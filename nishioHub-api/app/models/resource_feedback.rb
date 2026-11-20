class ResourceFeedback < ApplicationRecord
  belongs_to :platform_resource
  belongs_to :user
  validates :user_id, uniqueness: { scope: :platform_resource_id }
  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :comment, presence: true, length: { maximum: 1000 }
end
