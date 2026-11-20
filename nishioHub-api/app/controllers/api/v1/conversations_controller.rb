class Api::V1::ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :staff_write_permission,only:%i[create create_message]
  before_action {response.headers['Cache-Control']='private, no-store'}
  before_action :record_presence
  before_action :set_conversation, only: %i[show messages create_message mark_read attachment]

  def index
    scope = current_user.conversations.where(conversation_memberships:{deleted_at:nil}).includes(conversation_memberships: { user: [:role, :profile] })
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(200))}%"
      scope = scope.where(<<~SQL.squish, q: term)
        conversations.title ILIKE :q OR EXISTS (
          SELECT 1 FROM conversation_memberships cm JOIN users u ON u.id = cm.user_id
          WHERE cm.conversation_id = conversations.id AND u.full_name ILIKE :q
        ) OR EXISTS (
          SELECT 1 FROM chat_messages m WHERE m.conversation_id = conversations.id AND m.content ILIKE :q
        )
      SQL
    end
    page = [[params.fetch(:page, 1).to_i, 1].max, 10000].min
    total = scope.count
    conversations = scope.order(Arel.sql("COALESCE(last_message_at, conversations.created_at) DESC"), id: :desc).offset((page - 1) * 30).limit(30)
    render json: { conversations: conversations.map { |conversation| serialize(conversation) }, meta: { page: page, total: total, total_pages: (total / 30.0).ceil } }
  end

  def unread_count
    total = ChatMessage.joins(conversation: :conversation_memberships)
      .where(conversation_memberships: { user_id: current_user.id }).where.not(sender_id: current_user.id)
      .where(conversation_memberships:{deleted_at:nil}).where("chat_messages.id > conversation_memberships.last_read_message_id AND chat_messages.id > conversation_memberships.deleted_through_message_id").count
    render json: { unread: total }
  end

  def contacts
    scope = User.where(is_active: true).where.not(id: current_user.id).includes(:role, :profile)
    known_ids = ConversationMembership.where(conversation_id: current_user.conversation_memberships.select(:conversation_id)).select(:user_id)
    blocked=MessagingBlock.where(blocker_id:current_user.id).select(:blocked_id)
    blockers=MessagingBlock.where(blocked_id:current_user.id).select(:blocker_id)
    scope=scope.where.not(id:blocked).where.not(id:blockers)
    scope = scope.left_joins(:account_setting).where("account_settings.allow_contact_requests IS NOT FALSE OR users.id IN (?)", known_ids)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
      scope = scope.where("full_name ILIKE ?", term)
    else
      ids = current_user.mentee_bookings.select(:mentor_id).map(&:mentor_id) + current_user.mentor_bookings.select(:mentee_id).map(&:mentee_id)
      ids += ConversationMembership.where(conversation_id: current_user.conversation_memberships.select(:conversation_id)).pluck(:user_id)
      scope = scope.where(id: ids.uniq)
    end
    render json: scope.order(:full_name).limit(30).map { |person| ConversationSerializer.person_json(person) }
  end

  def create
    raw_ids = params[:participant_ids]
    unless raw_ids.is_a?(Array) && raw_ids.size <= 30 && raw_ids.all? { |id| id.is_a?(Integer) && id.positive? || id.is_a?(String) && id.match?(/\A[1-9]\d*\z/) }
      return render_error("Choose valid conversation participants", :unprocessable_entity)
    end
    ids = raw_ids.map(&:to_i).uniq - [current_user.id]
    kind = params[:kind].presence || "direct"
    return render_error("Choose one other person for a direct conversation", :unprocessable_entity) if kind == "direct" && ids.size != 1
    return render_error("Choose between 2 and 29 other group members", :unprocessable_entity) if kind == "group" && !ids.size.between?(2, 29)
    return render_error("Invalid conversation type", :unprocessable_entity) unless kind.in?(%w[direct group])

    people = User.where(id: ids, is_active: true)
    return render_error("One or more participants are unavailable", :unprocessable_entity) unless people.count == ids.size
    known_ids = ConversationMembership.where(conversation_id: current_user.conversation_memberships.select(:conversation_id)).pluck(:user_id)
    if people.includes(:account_setting).any? { |person| person.account_setting&.allow_contact_requests == false && !known_ids.include?(person.id) }
      return render_error("One or more participants are not accepting new conversations", :unprocessable_entity)
    end

    conversation = nil
    # Serialize direct-conversation creation even when the two users start it simultaneously.
    User.transaction do
      User.where(id: (ids + [current_user.id]).sort).order(:id).lock.load
      MessagingDelivery.people!(current_user,ids)
      key = kind == "direct" ? (ids + [current_user.id]).sort.join(":") : nil
      conversation = key && Conversation.find_by(direct_key: key)
      unless conversation
        conversation = Conversation.create!(creator: current_user, kind: kind, title: kind == "group" ? params[:title] : nil, direct_key: key)
        (ids + [current_user.id]).each { |id| conversation.conversation_memberships.create!(user_id: id) }
      end
    end
    conversation.conversation_memberships.find_by!(user:current_user).update!(deleted_at:nil)
    render json: serialize(conversation), status: :ok
  end

  def show
    render json: serialize(@conversation)
  end

  def messages
    scope = @conversation.chat_messages.where("chat_messages.id > ?",own_membership.deleted_through_message_id).includes(:sender, attachment_attachment: :blob)
    scope = scope.where("id < ?", params[:before_id].to_i) if params[:before_id].present?
    selected = scope.order(id: :desc).limit(51).to_a
    has_more = selected.size > 50
    selected = selected.first(50).reverse
    memberships = @conversation.conversation_memberships.to_a
    render json: { messages: selected.map { |message| ChatMessageSerializer.new(message, memberships: memberships).as_json },
      has_more: has_more, oldest_id: selected.first&.id }
  end

  def create_message
    source = params.require(:message).permit(:content, :client_nonce, :attachment)
    if source[:attachment].present? && !source[:attachment].is_a?(ActionDispatch::Http::UploadedFile)
      return render_error("Upload a PDF, image, or text file", :unprocessable_entity)
    end
    nonce = source[:client_nonce].presence
    message = nil
    @conversation.with_lock do
      message = nonce && @conversation.chat_messages.find_by(sender: current_user, client_nonce: nonce)
      unless message
        message = @conversation.chat_messages.new(sender: current_user, content: source[:content], client_nonce: nonce)
        message.attachment=ChatMessage.upload!(source[:attachment]) if source[:attachment].present?
        message.save!
      end
    end
    render json: ChatMessageSerializer.new(message).as_json, status: :created
  end

  def mark_read
    message_id = params.require(:last_message_id).to_s
    return render_error("Invalid message ID", :unprocessable_entity) unless message_id.match?(/\A[1-9]\d*\z/)

    message = @conversation.chat_messages.where("id > ?",own_membership.deleted_through_message_id).find(message_id)
    membership = current_user.conversation_memberships.find_by!(conversation: @conversation)
    membership.with_lock { membership.update_columns(last_read_message_id: [membership.last_read_message_id, message.id].max, updated_at: Time.current) }
    read_sources = @conversation.chat_messages.where("id <= ?", message.id).select("CONCAT('chat-message-', id)")
    current_user.notifications.where(source_key: read_sources).update_all(read: true, updated_at: Time.current)
    render json: { last_read_message_id: membership.last_read_message_id }
  end

  def attachment
    message = @conversation.chat_messages.where("id > ?",own_membership.deleted_through_message_id).find(params[:message_id])
    return render_error("Attachment not found", :not_found) unless message.attachment.attached?

    send_data message.attachment.download, filename: message.attachment.filename.to_s, type: message.attachment.content_type, disposition: "attachment"
  end

  private

  def record_presence
    current_user.update_column(:last_active_at, Time.current) if current_user.last_active_at.nil? || current_user.last_active_at < 30.seconds.ago
  end

  def staff_write_permission
    if current_user&.platform_admin?
      Administration.authorize!(current_user,'dashboard.read')
      Administration.authorize!(current_user,'dashboard.manage')
    end
  end
  def own_membership = current_user.conversation_memberships.find_by!(conversation:@conversation)
  def set_conversation
    @conversation = current_user.conversations.where(conversation_memberships:{deleted_at:nil}).includes(conversation_memberships: { user: [:role, :profile] }).find(params[:id])
  end

  def serialize(conversation)
    ConversationSerializer.new(conversation, user: current_user).as_json
  end
end
