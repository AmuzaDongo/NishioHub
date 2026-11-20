class EventMaterial < ApplicationRecord
  belongs_to :event
  has_one_attached :file
  scope :active, -> {where(is_active:true)}
  TYPES=(SessionAsset::MATERIAL_TYPES+SessionAsset::RECORDING_TYPES).freeze
  validates :title, presence:true, length:{maximum:200}
  validates :description, length:{maximum:2000}
  validates :url, length:{maximum:2048}
  validate do
    errors.add(:base,'Add a file or a URL, not both') unless file.attached? ^ url.present?
    if url.present?
      uri=URI.parse(url) rescue nil
      errors.add(:url,'must be an HTTP(S) URL without credentials') unless uri.is_a?(URI::HTTP)&&uri.host.present?&&uri.userinfo.nil?
    end
    if file.attached?
      errors.add(:file,'has an unsupported format') unless TYPES.include?(file.blob.content_type)
      errors.add(:file,'exceeds the platform upload limit') if file.blob.byte_size>[SystemSetting.config['max_upload_mb'],10].min.megabytes
    end
  end
end
