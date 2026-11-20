class PlatformResourceAccess < ApplicationRecord
  belongs_to :user
  belongs_to :platform_resource
  validates :kind, inclusion: { in: %w[download link view] }
end
