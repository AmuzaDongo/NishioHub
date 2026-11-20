class ConversationSerializer
  def initialize(conversation, user:)
    @conversation = conversation
    @user = user
  end

  def as_json(*)
    members = @conversation.conversation_memberships.to_a
    membership = members.find { |member| member.user_id == @user.id }
    other = members.find { |member| member.user_id != @user.id }&.user
    latest = @conversation.chat_messages.where("id > ?",membership&.deleted_through_message_id||0).includes(:sender, attachment_attachment: :blob).order(id: :desc).first
    {
      id: @conversation.id, kind: @conversation.kind,
      title: @conversation.kind == "group" ? @conversation.title : other&.full_name,
      last_message_at: (@conversation.last_message_at || @conversation.created_at).iso8601,
      unread_count: @conversation.chat_messages.where.not(sender_id: @user.id).where("id > ?", [membership&.last_read_message_id||0,membership&.deleted_through_message_id||0].max).count,
      members: members.map { |member| self.class.person_json(member.user) },
      last_message: latest && ChatMessageSerializer.new(latest, memberships: members).as_json
    }
  end

  def self.person_json(user)
    visible = user.account_setting&.show_online_status != false
    { id: user.id, name: user.full_name, role: user.role&.name, avatar: user.avatar_url,
      last_active_at: visible ? user.last_active_at&.iso8601 : nil,
      online: visible && user.last_active_at.present? && user.last_active_at >= 90.seconds.ago }
  end
end
