class PlatformResource < ApplicationRecord
  validate { ResourceLibraryDetails.validate(self); ResourcePageDetails.validate(self) }
  has_many :resource_comments, dependent: :destroy
  has_many :resource_bookmarks, dependent: :destroy
  DOCUMENT_TYPES = %w[application/pdf text/plain application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet application/vnd.ms-powerpoint application/vnd.openxmlformats-officedocument.presentationml.presentation].freeze
  VIDEO_TYPES = %w[video/mp4 video/webm].freeze
  OTHER_TYPES = %w[image/jpeg image/png image/webp audio/mpeg audio/ogg].freeze
  TYPES = (DOCUMENT_TYPES + VIDEO_TYPES + OTHER_TYPES).freeze
  RESOURCE_TYPES = %w[course video document link other].freeze
  attr_accessor :type_explicit, :version_actor
  has_one_attached :thumbnail
  has_one_attached :captions
  has_many :resource_contents, dependent: :destroy
  has_many :resource_program_shares, dependent: :destroy
  has_many :resource_progresses, dependent: :destroy
  has_many :resource_feedbacks, dependent: :destroy
  has_many :resource_versions, dependent: :destroy
  scope :kept, -> { where(deleted_at: nil) }
  validates :language, format: { with: /\A[a-zA-Z]{2,3}(?:-[a-zA-Z0-9]{2,8})*\z/ }, length: { maximum: 35 }
  validates :visibility, inclusion: { in: %w[platform program staff] }
  validates :target_audience, :awards, length: { maximum: 500 }
  validates :module_name, length: { maximum: 200 }
  validates :position, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10000 }, allow_nil: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 604800 }, allow_nil: true
  validates :required, inclusion: { in: [true, false] }
  before_save { self.published_at ||= Time.current if published? && (new_record? || will_save_change_to_published?) }
  validate do
    errors.add(:visibility, 'requires a program assignment or share') if visibility == 'program' && platform_program_id.nil? && resource_program_shares.empty?
    errors.add(:published, 'cannot be true for a deleted resource') if deleted_at && published?
    errors.add(:duration_seconds, 'must include all chapter start times') if duration_seconds && resource_contents.where('start_seconds > ?', duration_seconds).exists?
    if thumbnail.attached?
      errors.add(:thumbnail, 'must be a JPEG, PNG or WebP up to 2 MB') unless %w[image/jpeg image/png image/webp].include?(thumbnail.blob.content_type) && thumbnail.blob.byte_size <= 2.megabytes
    end
    if captions.attached?
      errors.add(:captions, 'must be a WebVTT file up to 1 MB') unless %w[text/vtt text/plain].include?(captions.blob.content_type) && captions.blob.byte_size <= 1.megabyte
    end
  end
  def self.accessible_to(user)
    scope = kept.where(published: true, archived: false)
    return scope if user.platform_admin? && user.management_permission?('dashboard.read')
    programs = ProgramMembership.active.where(user: user).pluck(:platform_program_id)
    mentored = ProgramMentorAssignment.active.where(user: user).pluck(:platform_program_id)
    scope.where("visibility = 'platform' OR (visibility = 'program' AND (platform_program_id IN (:programs) OR platform_program_id IN (:mentored) OR id IN (SELECT platform_resource_id FROM resource_program_shares WHERE platform_program_id IN (:programs) OR platform_program_id IN (:mentored))))", programs: programs, mentored: mentored)
  end
  def track_access!(user, kind)
    return if user.platform_admin?
    with_lock do
      PlatformResourceAccess.create!(platform_resource: self, user: user, kind: kind)
      progress = resource_progresses.find_or_create_by!(user: user) { |p| p.percent = 1 }
      progress.update!(percent: 1) if progress.percent.zero?
    end
  end
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :platform_program, optional: true
  has_many :platform_resource_accesses, dependent: :destroy
  has_one_attached :file
  after_save { ResourceVersion.capture!(self, version_actor || (created_by if previously_new_record?)) }
  before_validation :infer_legacy_type
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :published, :archived, inclusion: { in: [true, false] }
  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
  validates :url, length: { maximum: 2048 }, allow_blank: true
  validate :has_content
  validate do
    errors.add(:published, 'cannot be true for archived resources') if archived? && published?
    errors.add(:tags, 'must contain up to 20 nonempty tags of 40 characters') unless tags.is_a?(Array) && tags.size <= 20 && tags.all? { |v| v.is_a?(String) && v.present? && v.length <= 40 }
  end
  def file_limit
    [SystemSetting.config['max_upload_mb'].to_i, resource_type.in?(%w[video course]) ? 100 : 10].min.megabytes
  end
  private
  def infer_legacy_type
    return if type_explicit || resource_type != 'link' || !file.attached?
    self.resource_type = VIDEO_TYPES.include?(file.blob.content_type) ? 'video' : DOCUMENT_TYPES.include?(file.blob.content_type) ? 'document' : 'other'
  end
  def has_content
    errors.add(:base, 'Add a resource file or URL') if url.blank? && !file.attached?
    if resource_type == 'link' && file.attached?
      errors.add(:file, 'cannot be attached to a Link resource; choose another type')
    end
    if url.present?
      uri = URI.parse(url) rescue nil
      errors.add(:url, 'must be an HTTP or HTTPS URL') unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    end
    return unless file.attached?
    allowed = case resource_type
    when 'video' then VIDEO_TYPES
    when 'document' then DOCUMENT_TYPES
    when 'other' then OTHER_TYPES + DOCUMENT_TYPES
    else TYPES
    end
    errors.add(:file, 'has an unsupported format for this resource type') unless allowed.include?(file.blob.content_type)
    errors.add(:file, 'exceeds the resource or platform upload limit') if file.blob.byte_size > file_limit
  end
end
