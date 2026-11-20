class SessionFeedback < ApplicationRecord
  belongs_to :booking
  belongs_to :user
  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :rating, inclusion: { in: 1..5 }
  validates :comment, presence: true, length: { maximum: 500 }
  validates :user_id, uniqueness: { scope: :booking_id }
end
