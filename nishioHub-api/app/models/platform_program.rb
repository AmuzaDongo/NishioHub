class PlatformProgram < ApplicationRecord
  validate { ProgramPublicDetails.validate(self) }
  AUDIENCE_STAGES=%w[primary secondary university career professionals].freeze
  THEMES=%w[career_guidance academic_support digital_skills entrepreneurship leadership wellbeing industry_exposure innovation].freeze
  validates :featured, inclusion: {in:[true,false]}
  validate do
    {audience_stages:AUDIENCE_STAGES,themes:THEMES}.each do |field,allowed|
      value=public_send(field)
      errors.add(field,'must contain unique supported tags') unless value.is_a?(Array)&&value.uniq==value&&(value-allowed).empty?
    end
  end
  ICONS = %w[graduation chart code sprout users briefcase].freeze
  has_one_attached :banner
  validate :valid_banner

  def banner_url
    "/api/v1/platform/programs/#{id}/banner?version=#{lock_version}" if banner.attached?
  end

  def valid_banner
    return unless banner.attached?
    unless %w[image/jpeg image/png image/webp].include?(banner.blob.content_type)&&banner.blob.byte_size<=2.megabytes
      errors.add(:banner,'must be a JPEG, PNG or WebP image up to 2 MB')
    end
  end
  has_many :program_goals, dependent: :destroy
  has_many :mentee_goals, dependent: :nullify
  has_many :mentor_goals, dependent: :nullify
  belongs_to :category, optional: true
  has_many :program_mentor_assignments, dependent: :destroy
  validates :icon, inclusion: { in: ICONS }
  validates :capacity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1_000_000 }, allow_nil: true
  validates :target_audience, length: { maximum: 500 }
  validates :delivery_mode, inclusion: { in: %w[online in_person hybrid] }
  validate :details_valid
  def details_valid
    unless objectives.is_a?(Array) && objectives.size <= 20 && objectives.all? { |v| v.is_a?(String) && v.present? && v.length <= 300 }
      errors.add(:objectives, 'must contain up to 20 nonempty objectives of at most 300 characters')
    end
    if capacity && persisted? && capacity < program_memberships.where(is_active: true, user_id: User.with_role('mentee').select(:id)).count
      errors.add(:capacity, 'cannot be below current enrollment')
    end
    [[registration_starts_on, registration_ends_on], [evaluation_starts_on, evaluation_ends_on]].each do |first, last|
      errors.add(:base, 'Schedule end dates must be on or after their start dates') if first && last && last < first
    end
    errors.add(:registration_ends_on, 'must be on or before the program start') if registration_ends_on && starts_on && registration_ends_on > starts_on
    errors.add(:evaluation_starts_on, 'must be on or after the program end') if evaluation_starts_on && ends_on && evaluation_starts_on < ends_on
  end
  validate :valid_date_inputs
  def valid_date_inputs
    %i[starts_on ends_on registration_starts_on registration_ends_on evaluation_starts_on evaluation_ends_on].each do |field|
      value = public_send("#{field}_before_type_cast")
      next if value.blank? || value.is_a?(Date) || value.is_a?(Time)
      valid = value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && (Date.iso8601(value) rescue nil)
      errors.add(field, 'must be a valid ISO date') unless valid
    end
  end
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :program_memberships, dependent: :destroy
  has_many :members, through: :program_memberships, source: :user
  has_many :bookings, dependent: :nullify
  has_many :platform_resources, dependent: :nullify
  validates :title, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 2000 }
  validates :status, inclusion: { in: %w[draft active archived] }
  validate :dates_in_order
  scope :active, -> { where(status: 'active') }
  private
  def dates_in_order
    errors.add(:ends_on, 'must be on or after the start date') if starts_on && ends_on && ends_on < starts_on
  end
end
