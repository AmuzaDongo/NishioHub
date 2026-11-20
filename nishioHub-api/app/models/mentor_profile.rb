class MentorProfile < ApplicationRecord
  CURRENCIES = %w[USD EUR GBP CAD AUD].freeze
  AVATAR_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  belongs_to :user
  has_many :mentor_skills, dependent: :destroy
  has_many :skills, through: :mentor_skills
  has_one_attached :avatar

  validates :user_id, uniqueness: true
  validates :title, presence: true, length: { maximum: 150 }
  validates :bio, length: { maximum: 2000 }, allow_blank: true
  validates :currency, inclusion: { in: CURRENCIES }, allow_blank: true
  validates :years_of_experience, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :languages_are_strings
  validate :timezone_is_valid
  validate :avatar_content_type
  validate :avatar_size

  private

  def languages_are_strings
    return if languages.blank?

    unless languages.is_a?(Array) && languages.all? { |language| language.is_a?(String) && language.strip.present? }
      errors.add(:languages, "must be an array of non-empty strings")
    end
  end

  def timezone_is_valid
    return if timezone.blank?

    errors.add(:timezone, "is not a valid timezone") if ActiveSupport::TimeZone[timezone].nil?
  end

  def avatar_content_type
    return unless avatar.attached?

    unless avatar.blob.content_type.in?(AVATAR_CONTENT_TYPES)
      errors.add(:avatar, "must be a JPEG, PNG, or WebP image")
    end
  end

  def avatar_size
    return unless avatar.attached?

    errors.add(:avatar, "must be smaller than 5 MB") if avatar.blob.byte_size > AVATAR_MAX_SIZE
  end
end
