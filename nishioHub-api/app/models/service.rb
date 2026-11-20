class Service < ApplicationRecord
  belongs_to :mentor, class_name: "User"
  belongs_to :category
  has_many :bookings, dependent: :destroy
  has_many :reviews, dependent: :destroy

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :duration, numericality: { greater_than: 0 }
  validate :mentor_must_have_mentor_role

  scope :active, -> { where(is_active: true) }

  private

  def mentor_must_have_mentor_role
    return if mentor.nil?

    errors.add(:mentor, "must have the mentor role") unless mentor.has_role?('mentor')
  end
end
