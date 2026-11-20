class AccountSetting < ApplicationRecord
  belongs_to :user
  validates :appearance, inclusion: { in: %w[light dark system] }
  validates :show_online_status, :allow_contact_requests, inclusion: { in: [true, false] }
  validates :learning_format, inclusion: { in: %w[mixed reading video practical] }
  validates :weekly_learning_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 30, less_than_or_equal_to: 600 }
  validates :session_preference, inclusion: { in: %w[online in_person either] }
  validates :mentorship_focus, length: { maximum: 200 }
end
