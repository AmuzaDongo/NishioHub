class ResourceBookmark < ApplicationRecord
  belongs_to :user
  belongs_to :platform_resource
  validates :platform_resource_id, uniqueness: {scope: :user_id}
end
