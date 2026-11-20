class Api::V1::AdminMessagesController < Api::V1::ConversationsController
  before_action :require_admin!
  before_action ->{Administration.authorize!(current_user,'dashboard.read')}
  before_action :set_conversation,only:%i[show messages create_message mark_read attachment state content block]
  def index
    memberships=current_user.conversation_memberships.where(deleted_at:nil)
    scope=current_user.conversations.where(id:memberships.select(:conversation_id))
    if params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(150))}%"
      scope=scope.where("conversations.title ILIKE :q OR EXISTS(SELECT 1 FROM conversation_memberships cm JOIN users u ON u.id=cm.user_id WHERE cm.conversation_id=conversations.id AND u.full_name ILIKE :q) OR EXISTS(SELECT 1 FROM chat_messages m WHERE m.conversation_id=conversations.id AND m.id > (SELECT deleted_through_message_id FROM conversation_memberships own WHERE own.user_id=:uid AND own.conversation_id=conversations.id) AND m.content ILIKE :q)",q:term,uid:current_user.id)
    end
    counts=%w[all unread starred archived].to_h{|tab|[tab,filtered(scope,tab).count]}
    scope=filtered(scope,params[:tab].presence||'all');total=scope.count
    items=scope.includes(conversation_memberships:{user:[:role,:profile]}).order(Arel.sql('COALESCE(last_message_at,conversations.created_at) DESC,conversations.id DESC')).limit(8).offset((page-1)*8)
    render json:{conversations:items.map{|c|serialize(c)},counts:counts,meta:{page:page,per_page:8,total:total,total_pages:(total/8.0).ceil},capabilities:{manage:current_user.management_permission?('dashboard.manage')}}
  end
  def contacts
    known=ConversationMembership.where(conversation_id:current_user.conversation_memberships.select(:conversation_id)).select(:user_id)
    scope=User.where(is_active:true).where.not(id:current_user.id).left_joins(:account_setting).where('account_settings.allow_contact_requests IS NOT FALSE OR users.id IN (?)',known)
    scope=scope.where.not(id:MessagingBlock.where(blocker_id:current_user.id).select(:blocked_id)).where.not(id:MessagingBlock.where(blocked_id:current_user.id).select(:blocker_id))
    if params[:role].present?&&params[:role]!='all'
      raise Administration::Rejected.new('Choose mentor, mentee or all contacts',:unprocessable_entity) unless %w[mentor mentee].include?(params[:role])
      scope=scope.where(id:User.with_role(params[:role]).select(:id))
    end
    if params[:program_id].present?
      program_id=AdminMenteeQuery.positive_id!(params[:program_id])
      scope=scope.where(id:ProgramMembership.where(platform_program_id:program_id,is_active:true).select(:user_id)).or(scope.where(id:ProgramMentorAssignment.where(platform_program_id:program_id,is_active:true).select(:user_id)))
    end
    if params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%";scope=scope.where('users.full_name ILIKE :q OR users.email ILIKE :q',q:term)
    end
    total=scope.count
    render json:{people:scope.includes(:role,:profile).order(:full_name,:id).limit(20).offset((page-1)*20).map{|u|ConversationSerializer.person_json(u)},meta:{page:page,per_page:20,total:total,total_pages:(total/20.0).ceil}}
  end
  def create
    conversation=nil
    write do
      ids=recipient_ids!(params[:participant_ids],29)
      kind=params[:kind].presence||'direct'
      raise Administration::Rejected.new('Choose one direct contact or 2–29 group members',:unprocessable_entity) unless kind=='direct'&&ids.size==1 || kind=='group'&&ids.size.between?(2,29)
      User.where(id:(ids+[current_user.id]).sort).order(:id).lock.load
      people=MessagingDelivery.people!(current_user,ids)
      if kind=='direct'
        conversation=MessagingDelivery.direct!(current_user,people.first)
      else
        program=PlatformProgram.active.find(AdminMenteeQuery.positive_id!(params[:program_id])) if params[:program_id].present?
        conversation=Conversation.create!(creator:current_user,kind:'group',title:params[:title],platform_program:program,cohort_label:params[:cohort_label])
        (ids+[current_user.id]).each{|uid|conversation.conversation_memberships.create!(user_id:uid)}
      end
      Administration.audit!(current_user,'messaging.conversation_started',conversation,{kind:kind})
    end
    render json:serialize(conversation)
  end
  def create_message
    write{super}
  end
  def state
    write do
      @conversation.lock!;member=own_membership;member.lock!
      AdminGoalManagement.revision!(member,params[:lock_version])
      source=params.require(:state)
      raise Administration::Rejected.new('State must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
      attrs=source.permit(:starred,:archived,:muted).to_h
      if source[:deleted]==true
        latest=@conversation.chat_messages.maximum(:id)||0
        attrs.merge!(deleted_at:Time.current,deleted_through_message_id:latest,last_read_message_id:[member.last_read_message_id,latest].max)
        sources=@conversation.chat_messages.select("CONCAT('chat-message-',id)")
        current_user.notifications.where(source_key:sources).update_all(read:true,updated_at:Time.current)
      end
      member.update!(attrs)
      Administration.audit!(current_user,'messaging.inbox_updated',@conversation,source.permit(:starred,:archived,:muted,:deleted).to_h)
    end
    head :no_content
  end
  def block
    write do
      raise Administration::Rejected.new('Block a direct contact; group members remain visible in their shared groups',:unprocessable_entity) unless @conversation.kind=='direct'
      peer=@conversation.users.where.not(id:current_user.id).first!
      User.where(id:[current_user.id,peer.id].sort).order(:id).lock.load
      @conversation.lock!
      if params[:blocked]==false
        MessagingBlock.where(blocker:current_user,blocked:peer).destroy_all
      elsif params[:blocked]==true
        MessagingBlock.find_or_create_by!(blocker:current_user,blocked:peer)
      else
        raise Administration::Rejected.new('Choose a valid block state',:unprocessable_entity)
      end
      Administration.audit!(current_user,'messaging.block_updated',@conversation,{blocked:params[:blocked],peer_id:peer.id})
    end
    head :no_content
  end
  def content
    scope=@conversation.chat_messages.where('chat_messages.id > ?',own_membership.deleted_through_message_id).joins(:attachment_attachment).includes(:sender,attachment_attachment: :blob).order(id: :desc)
    render json:{items:scope.limit(10).offset((page-1)*10).map{|m|ChatMessageSerializer.new(m).as_json},meta:{page:page,per_page:10,total:scope.count,total_pages:(scope.count/10.0).ceil}}
  end
  def preferences
    preference=current_user.messaging_preference
    render json:preference ? preference.as_json(only:%i[notify_messages send_read_receipts enter_to_send lock_version]) : {notify_messages:true,send_read_receipts:true,enter_to_send:true,lock_version:0}
  end
  def update_preferences
    source=params.require(:preferences)
    raise Administration::Rejected.new('Preferences must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    write do
      preference=MessagingPreference.find_or_create_by!(user:current_user);preference.lock!;AdminGoalManagement.revision!(preference,source[:lock_version]);preference.update!(source.permit(:notify_messages,:send_read_receipts,:enter_to_send))
    end
    preferences
  end
  def broadcast
    broadcast=nil
    write do
      ids=recipient_ids!(params[:recipient_ids],100).sort
      title=params[:title].to_s.strip;body=params[:content].to_s.strip;nonce=params[:client_nonce].to_s
      raise Administration::Rejected.new('A request identifier is required',:unprocessable_entity) if nonce.blank?||nonce.length>100
      broadcast=current_user.message_broadcasts.find_by(client_nonce:nonce)
      if broadcast
        unless broadcast.recipient_ids==ids&&broadcast.title==title&&broadcast.content==body
          raise Administration::Rejected.new('This broadcast request already has different content',:conflict)
        end
      else
        User.where(id:(ids+[current_user.id]).sort).order(:id).lock.load
        people=MessagingDelivery.people!(current_user,ids)
        broadcast=current_user.message_broadcasts.create!(client_nonce:nonce,title:title,content:body,recipient_ids:ids)
        conversations=people.map do |peer|
          c=MessagingDelivery.direct!(current_user,peer)
          c.with_lock{c.chat_messages.create!(sender:current_user,content:[title.presence,body].compact.join("\n\n"),client_nonce:"broadcast-#{broadcast.id}")}
          c.id
        end
        broadcast.update!(conversation_ids:conversations)
        Administration.audit!(current_user,'messaging.broadcast_sent',broadcast,{recipient_count:ids.length})
      end
    end
    render json:{id:broadcast.id,delivered:broadcast.recipient_ids.size,conversation_ids:broadcast.conversation_ids}
  end
  private
  def write
    Administration.transaction do
      current_user.reload;Administration.authorize!(current_user,'dashboard.read');Administration.authorize!(current_user,'dashboard.manage');yield
    end
  end
  def recipient_ids!(raw,max)
    unless raw.is_a?(Array)&&raw.size.between?(1,max)&&raw.map(&:to_s).uniq.size==raw.size
      raise Administration::Rejected.new("Choose 1–#{max} distinct recipients",:unprocessable_entity)
    end
    ids=raw.map{|id|AdminMenteeQuery.positive_id!(id)}
    raise Administration::Rejected.new('Choose other users as recipients',:unprocessable_entity) if ids.include?(current_user.id)
    ids
  end
  def page
    raw=params.fetch(:page,1).to_s
    raise Administration::Rejected.new('Invalid page',:unprocessable_entity) unless raw.match?(/\A\d+\z/)&&raw.to_i.between?(1,10000)
    raw.to_i
  end
  def filtered(scope,tab)
    own=current_user.conversation_memberships
    case tab
    when 'all' then scope.where(id:own.where(archived:false).select(:conversation_id))
    when 'archived' then scope.where(id:own.where(archived:true).select(:conversation_id))
    when 'starred' then scope.where(id:own.where(starred:true,archived:false).select(:conversation_id))
    when 'unread' then scope.where(id:own.where(archived:false).select(:conversation_id)).where('EXISTS(SELECT 1 FROM chat_messages m JOIN conversation_memberships cm ON cm.conversation_id=m.conversation_id WHERE m.conversation_id=conversations.id AND cm.user_id=? AND m.sender_id<>? AND m.id>cm.last_read_message_id AND m.id>cm.deleted_through_message_id)',current_user.id,current_user.id)
    else raise Administration::Rejected.new('Choose all, unread, starred or archived conversations',:unprocessable_entity)
    end
  end
  def serialize(conversation)
    member=conversation.conversation_memberships.find{|m|m.user_id==current_user.id}||conversation.conversation_memberships.find_by!(user:current_user)
    peer=conversation.users.where.not(id:current_user.id).first if conversation.kind=='direct'
    program=conversation.platform_program||peer&.mentee_profile&.primary_program
    about=peer&&{email:peer.email,phone:peer.phone_number,location:peer.location.presence||peer.mentee_profile&.location.presence||peer.profile&.city,program:program&&{id:program.id,title:program.title},cohort:conversation.cohort_label}
    meeting=nil
    if peer
      booking=Booking.where(status:'confirmed').where('(mentor_id=? AND mentee_id=?) OR (mentor_id=? AND mentee_id=?)',current_user.id,peer.id,peer.id,current_user.id).where('scheduled_at <= ? AND scheduled_at + duration * INTERVAL \'1 minute\' > ?',15.minutes.from_now,Time.current).where.not(meeting_url:[nil,'']).order(scheduled_at: :asc).first
      meeting=booking&.meeting_url
      uri=URI.parse(meeting.to_s) rescue nil
      meeting=nil unless uri.is_a?(URI::HTTP)&&uri.host.present?&&uri.userinfo.nil?
    end
    super.merge(starred:member.starred,archived:member.archived,muted:member.muted,lock_version:member.lock_version,blocked:!!(peer&&MessagingBlock.exists?(blocker:current_user,blocked:peer)),can_send:current_user.management_permission?('dashboard.manage')&&(!peer||peer.is_active?)&&!(peer&&MessagingBlock.between?(current_user.id,peer.id)),about:about,program:program&&{id:program.id,title:program.title},cohort:conversation.cohort_label,meeting_url:meeting,capabilities:{manage:current_user.management_permission?('dashboard.manage')})
  end
end
