class Booking < ApplicationRecord
  attr_accessor :skip_participant_notifications
  STATUSES = %w[pending confirmed completed cancelled].freeze

  belongs_to :session_category, class_name: 'Category', optional: true
  belongs_to :platform_program, optional: true
  belongs_to :service
  belongs_to :mentee, class_name: "User"
  belongs_to :mentor, class_name: "User"
  has_one_attached :cover
  has_many :session_assets, dependent: :destroy
  has_many :session_feedbacks, dependent: :destroy
  has_many :session_notes, dependent: :destroy
  validates :session_title, presence: true, unless: -> { session_title.nil? }
  validate :valid_session_details
  def valid_session_details
    { objectives: [20, 300], session_tags: [12, 40] }.each do |key, (count, length)|
      value = public_send(key)
      errors.add(key, "must contain up to #{count} nonempty strings of #{length} characters") unless value.is_a?(Array) && value.size <= count && value.all? { |s| s.is_a?(String) && s.present? && s.length <= length }
    end
    [[registration_opens_at, registration_closes_at], [feedback_opens_at, feedback_closes_at]].each do |first, last|
      errors.add(:base, 'Schedule end must follow its start') if first && last && first > last
    end
    errors.add(:registration_closes_at, 'must not follow session start') if registration_closes_at && scheduled_at && registration_closes_at > scheduled_at
    errors.add(:feedback_opens_at, 'must not precede session end') if feedback_opens_at && scheduled_at && duration && feedback_opens_at < scheduled_at + duration.minutes
    if cover.attached?
      errors.add(:cover, 'must be a JPEG, PNG or WebP up to 2 MB') unless %w[image/jpeg image/png image/webp].include?(cover.blob.content_type) && cover.blob.byte_size <= 2.megabytes
    end
  end
  has_many :booking_participants, dependent: :destroy
  after_create :register_primary_participant
  validates :format, inclusion: { in: %w[online live on_site] }
  validates :session_title, length: { maximum: 100 }
  validates :session_description, length: { maximum: 2000 }
  validates :location, length: { maximum: 500 }
  validates :meeting_url, length: { maximum: 2048 }, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
  def register_primary_participant
    booking_participants.create!(user_id: mentee_id)
  end
  has_one :review, dependent: :destroy

  after_save -> { NotifyBookingParticipants.call(self) }, if: -> { !skip_participant_notifications && (previously_new_record? || saved_change_to_status?) }

  validates :status, inclusion: { in: STATUSES }
  validates :scheduled_at, :duration, :total_price, presence: true
  validates :duration, numericality: { greater_than: 0 }
  validates :total_price, numericality: { greater_than_or_equal_to: 0 }
end
