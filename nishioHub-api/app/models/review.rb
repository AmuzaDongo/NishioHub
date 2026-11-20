class Review < ApplicationRecord
  belongs_to :booking
  belongs_to :service
  belongs_to :mentor, class_name: "User"
  belongs_to :mentee, class_name: "User"

  validates :rating, inclusion: { in: 1..5 }
  validates :comment, presence: true, length: { maximum: 500 }
  validates :booking_id, uniqueness: true
end
