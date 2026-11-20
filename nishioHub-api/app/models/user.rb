class User < ApplicationRecord
  has_many :resource_bookmarks, dependent: :destroy
  has_many :resource_comments, dependent: :destroy
  has_one :mentor_application, dependent: :destroy
  has_many :reviewed_mentor_applications, class_name: "MentorApplication", foreign_key: :reviewed_by_id, dependent: :nullify
  has_many :saved_reports,dependent: :destroy
  has_many :report_schedules,dependent: :destroy
  has_many :report_runs,dependent: :destroy
  has_one :messaging_preference,dependent: :destroy
  has_many :outgoing_messaging_blocks,class_name:'MessagingBlock',foreign_key: :blocker_id,dependent: :destroy
  has_many :incoming_messaging_blocks,class_name:'MessagingBlock',foreign_key: :blocked_id,dependent: :destroy
  has_many :message_broadcasts,foreign_key: :sender_id,dependent: :destroy
  has_one :account_setting, dependent: :destroy
  has_one_attached :avatar
  belongs_to :role, optional: true
  has_many :user_role_assignments, dependent: :destroy
  has_many :additional_roles, through: :user_role_assignments, source: :role
  validates :bio, length: { maximum: 2000 }
  validates :location, length: { maximum: 150 }
  validates :website, length: { maximum: 2048 }
  validate do
    if website.present?
      uri = URI.parse(website) rescue nil
      errors.add(:website, 'must be an HTTP(S) URL without credentials') unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    end
  end
  validates :affiliation, length: { maximum: 150 }
  has_many :conversation_memberships, dependent: :destroy
  has_many :conversations, through: :conversation_memberships
  has_many :chat_messages, foreign_key: :sender_id, dependent: :destroy
  has_many :created_conversations, class_name: "Conversation", foreign_key: :creator_id, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_one :notification_preference, dependent: :destroy
  has_many :event_feedbacks, dependent: :destroy
  has_many :organized_events, class_name: "Event", foreign_key: :organizer_id, dependent: :destroy
  has_many :event_registrations, dependent: :destroy
  has_many :event_suggestions, dependent: :destroy
  has_many :achievement_awards, dependent: :destroy
  has_many :learning_enrollments, dependent: :destroy
  has_one :mentee_profile, dependent: :destroy
  has_many :mentee_goals, dependent: :destroy
  has_many :mentor_goals, dependent: :destroy
  has_many :mentorship_resources, dependent: :destroy
  has_one :profile, dependent: :destroy
  has_one :mentor_profile, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy
  has_many :services, foreign_key: :mentor_id, dependent: :destroy
  has_many :mentor_bookings, class_name: "Booking", foreign_key: :mentor_id, dependent: :destroy
  has_many :mentee_bookings, class_name: "Booking", foreign_key: :mentee_id, dependent: :destroy
  has_many :mentor_reviews, class_name: "Review", foreign_key: :mentor_id, dependent: :destroy
  has_many :given_reviews, class_name: "Review", foreign_key: :mentee_id, dependent: :destroy
  has_many :availability_slots, foreign_key: :mentor_id, dependent: :destroy

  validates :full_name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, uniqueness: true, length: { maximum: 100 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone_number, presence: true, uniqueness: true, length: { maximum: 13 }
  validates :hashed_password, presence: true

  def password=(plain)
    self.hashed_password = BCrypt::Password.create(plain)
  end

  def self.with_role(name)
    ids = Role.all.select { |role| role.canonical_name == name.to_s.downcase.gsub(/[ _-]/, '') }.map(&:id)
    where(role_id: ids).or(where(id: UserRoleAssignment.where(role_id: ids).select(:user_id)))
  end

  def effective_roles
    ([role] + additional_roles.to_a).compact.uniq(&:id)
  end

  def has_role?(name)
    effective_roles.any? { |candidate| candidate.canonical_name == name.to_s.downcase.gsub(/[ _-]/, '') }
  end

  def super_admin?
    has_role?('superadmin')
  end

  def platform_admin?
    super_admin? || has_role?('admin')
  end

  def management_permission?(permission)
    return false unless platform_admin?
    super_admin? || effective_roles.any? { |candidate| candidate.effective_permissions.include?(permission) }
  end

  def avatar_url
    return avatar.url if avatar.attached?
    return mentor_profile.avatar.url if mentor_profile&.avatar&.attached?

    profile&.profile_picture
  end

  def authenticate(plain)
    return false if hashed_password.blank? || plain.blank?

    BCrypt::Password.new(hashed_password) == plain
  rescue BCrypt::Errors::InvalidHash
    false
  end
end
