class ChatMessage < ApplicationRecord
  ATTACHMENT_TYPES = %w[application/pdf image/jpeg image/png image/webp text/plain video/mp4 application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.openxmlformats-officedocument.spreadsheetml.sheet].freeze
  belongs_to :conversation
  belongs_to :sender, class_name: "User"
  has_one_attached :attachment
  validates :content, length: { maximum: 5000 }
  validates :client_nonce, length: { maximum: 100 }
  validate :message_has_content
  validate :sender_is_member
  validate :attachment_is_supported
  after_create :update_conversation_and_notify
  validate do
    if conversation&.kind=='direct'&&conversation.users.where.not(id:sender_id).any?{|u|!u.is_active?}
      errors.add(:base,'Recipient is unavailable')
    end
    if conversation&.kind=='direct'&&conversation.users.where.not(id:sender_id).any?{|u|MessagingBlock.between?(sender_id,u.id)}
      errors.add(:base,'Messaging is blocked for this conversation')
    end
  end
  def self.upload!(file)
    limit=[SystemSetting.config['max_upload_mb'],10].min.megabytes
    raise Administration::Rejected.new('Choose a supported file within the 10 MB/platform limit',:unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile)&&file.size<=limit
    raise Administration::Rejected.new('Unsupported declared attachment format',:unprocessable_entity) unless (ATTACHMENT_TYPES+%w[application/octet-stream application/zip]).include?(file.content_type)
    type=Marcel::MimeType.for(file.tempfile);extension=File.extname(file.original_filename.to_s).downcase
    if GoalAttachment::OFFICE.key?(extension)
      header=file.tempfile.read(4);file.tempfile.rewind
      raise Administration::Rejected.new('Choose a valid Office document',:unprocessable_entity) unless header=="PK\x03\x04".b
      type=GoalAttachment::OFFICE[extension]
    elsif extension=='.txt'
      content=file.tempfile.read.force_encoding(Encoding::UTF_8);file.tempfile.rewind
      raise Administration::Rejected.new('Choose valid UTF-8 text',:unprocessable_entity) unless content.valid_encoding?&&!content.include?("\x00")
      type='text/plain'
    end
    raise Administration::Rejected.new('Unsupported attachment format',:unprocessable_entity) unless ATTACHMENT_TYPES.include?(type)
    {io:file.tempfile,filename:file.original_filename,content_type:type,identify:false}
  end

  private

  def message_has_content
    errors.add(:content, "or an attachment is required") if content.blank? && !attachment.attached?
  end

  def sender_is_member
    errors.add(:sender, "must belong to this conversation") unless conversation&.conversation_memberships&.exists?(user_id: sender_id)
  end

  def attachment_is_supported
    return unless attachment.attached?

    errors.add(:attachment, "must be a PDF, text file, JPEG, PNG, or WebP image") unless attachment.blob.content_type.in?(ATTACHMENT_TYPES)
    errors.add(:attachment, "must be 10 MB or smaller") if attachment.blob.byte_size > 10.megabytes
  end

  def update_conversation_and_notify
    conversation.update!(last_message_at: created_at)
    conversation.conversation_memberships.where.not(user_id:sender_id).where.not(deleted_at:nil).update_all(deleted_at:nil,archived:false,updated_at:Time.current)
    conversation.users.where.not(id: sender_id).each do |recipient|
      next if conversation.conversation_memberships.find_by(user_id:recipient.id)&.muted? || recipient.messaging_preference&.notify_messages==false
      Notification.deliver(user: recipient, source_key: "chat-message-#{id}", title: "New Message #{conversation.kind == 'group' ? "in #{conversation.title}" : "from #{sender.full_name}"}",
        message: content.presence || "Shared #{attachment.filename}", category: "mentorship", topic: "mentorship", icon: "users", href: "/messages/#{conversation_id}")
    end
  end
end
