class MenteeProfile < ApplicationRecord
  belongs_to :assigned_mentor, class_name: "User", optional: true
  belongs_to :primary_program, class_name: "PlatformProgram", optional: true
  validates :management_status, inclusion: { in: %w[active inactive graduated suspended] }
  before_validation do
    self.interests = interests.map(&:strip).uniq if interests.is_a?(Array) && interests.all? { |item| item.is_a?(String) }
  end
  validates :education, length: { maximum: 200 }
  validate :interests_are_valid
  def interests_are_valid
    unless interests.is_a?(Array) && interests.size <= 12 && interests.all? { |interest| interest.is_a?(String) && interest.strip.present? && interest.length <= 50 }
      errors.add(:interests, 'must contain up to 12 interests of 1–50 characters')
    end
  end
  belongs_to :user
  validates :school, :location, length: { maximum: 150 }
  validates :grade, length: { maximum: 50 }
  validates :vision, length: { maximum: 1000 }
  validates :bio, length: { maximum: 1000 }
end
