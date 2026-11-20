class BookingParticipant < ApplicationRecord
  belongs_to :booking
  belongs_to :user
  validates :user_id, uniqueness: { scope: :booking_id }
  validates :attended, inclusion: { in: [true, false] }, allow_nil: true
end
