class ResourceContent < ApplicationRecord
  belongs_to :platform_resource
  has_one_attached :file
  validates :public_listing, inclusion: {in:[true,false]}
  validate do
    if file.attached?
      allowed=PlatformResource::DOCUMENT_TYPES+PlatformResource::OTHER_TYPES
      errors.add(:file,'must be a supported document, image or audio file within the upload limit') unless allowed.include?(file.blob.content_type)&&file.byte_size<=[SystemSetting.config['max_upload_mb'].to_i,10].min.megabytes
    end
  end
  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 10000 }
  validates :position, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10000 }
  validates :start_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 604800 }, allow_nil: true
  validate do
    if url.present?
      uri = URI.parse(url) rescue nil
      errors.add(:url, 'must be an HTTP(S) URL without credentials') unless url.length <= 2048 && uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    end
    if start_seconds && platform_resource&.duration_seconds && start_seconds > platform_resource.duration_seconds
      errors.add(:start_seconds, 'must fit within the resource duration')
    end
  end
end
