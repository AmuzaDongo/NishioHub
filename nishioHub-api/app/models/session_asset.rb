class SessionAsset < ApplicationRecord
  MATERIAL_TYPES = %w[application/pdf text/plain image/jpeg image/png image/webp].freeze
  RECORDING_TYPES = %w[video/mp4 video/webm audio/mpeg audio/ogg].freeze
  belongs_to :booking
  has_one_attached :file
  has_many :session_asset_accesses, dependent: :destroy
  scope :active, -> { where(is_active: true) }
  validates :kind, inclusion: { in: %w[material recording] }
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :url, length: { maximum: 2048 }, allow_blank: true
  validate :valid_content
  def valid_content
    errors.add(:base, 'Add a file or URL, not both') unless file.attached? ^ url.present?
    if url.present?
      uri = URI.parse(url) rescue nil
      errors.add(:url, 'must be an HTTP or HTTPS URL without credentials') unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    end
    return unless file.attached?
    allowed = kind == 'recording' ? RECORDING_TYPES : MATERIAL_TYPES
    limit = [SystemSetting.config['max_upload_mb'].to_i, kind == 'recording' ? 100 : 10].min.megabytes
    errors.add(:file, 'has an unsupported format') unless allowed.include?(file.blob.content_type)
    errors.add(:file, 'is too large') if file.blob.byte_size > limit
  end
end
