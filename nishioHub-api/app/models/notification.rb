class Notification < ApplicationRecord
  CATEGORIES = %w[mentorship learning events system].freeze
  belongs_to :user
  validates :read, inclusion: { in: [true, false] }
  validates :title, presence: true, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 2000 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :topic, inclusion: { in: NotificationPreference::TOPICS }
  validates :icon, inclusion: { in: %w[users graduation calendar target medal book megaphone bell] }
  validates :href, format: { with: /\A\/(?!\/)[a-zA-Z0-9?&=\/_.%#-]*\z/ }

  def self.deliver(user:, source_key:, title:, message:, category:, topic:, icon:, href:, created_at: Time.current)
    return unless SystemSetting.config['notifications_enabled']
    return if user.notification_preference&.public_send(topic) == false

    create_or_find_by!(user: user, source_key: source_key) do |notification|
      notification.assign_attributes(title: title.to_s.truncate(200), message: message.to_s.truncate(2000),
        category: category, topic: topic, icon: icon, href: href, created_at: created_at)
    end
  end
end
