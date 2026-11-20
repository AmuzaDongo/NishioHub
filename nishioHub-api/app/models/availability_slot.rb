class AvailabilitySlot < ApplicationRecord
  belongs_to :mentor, class_name: "User"

  validates :starts_at, :ends_at, presence: true
  validate :ends_after_starts

  scope :available, -> { where(is_booked: false).where("starts_at > ?", Time.current) }

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
end
