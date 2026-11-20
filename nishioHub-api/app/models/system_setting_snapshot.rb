class SystemSettingSnapshot < ApplicationRecord
  belongs_to :created_by, class_name: 'User', optional: true
  validates :label, presence: true, length: { maximum: 100 }
  validates :values, :checksum, :revision, presence: true

  def document
    { format: 'nishiohub-system-settings', schema_version: 1, values: values, checksum: checksum, created_at: created_at.iso8601 }
  end

  def self.digest(values)
    Digest::SHA256.hexdigest(JSON.generate(values.sort.to_h))
  end
end
