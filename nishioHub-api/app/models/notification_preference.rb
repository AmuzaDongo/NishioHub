class NotificationPreference < ApplicationRecord
  TOPICS = %w[mentorship learning events goals platform].freeze
  belongs_to :user
  validates(*TOPICS, inclusion: { in: [true, false] })
end
