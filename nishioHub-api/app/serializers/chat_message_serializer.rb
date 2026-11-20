class ChatMessageSerializer
  def initialize(message, memberships: nil)
    @message = message
    @memberships = memberships || message.conversation.conversation_memberships.to_a
  end

  def as_json(*)
    {
      id: @message.id, conversation_id: @message.conversation_id, sender_id: @message.sender_id,
      sender_name: @message.sender.full_name, content: @message.content, created_at: @message.created_at.iso8601,
      read_by: @memberships.select { |member| member.user_id != @message.sender_id && member.last_read_message_id >= @message.id && member.user.messaging_preference&.send_read_receipts != false }.map(&:user_id),
      attachment: @message.attachment.attached? ? {
        filename: @message.attachment.filename.to_s, content_type: @message.attachment.content_type,
        byte_size: @message.attachment.byte_size,
        download_path: "/conversations/#{@message.conversation_id}/messages/#{@message.id}/attachment"
      } : nil
    }
  end
end
