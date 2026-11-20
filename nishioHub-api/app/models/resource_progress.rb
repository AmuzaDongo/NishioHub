class ResourceProgress < ApplicationRecord
  belongs_to :platform_resource
  belongs_to :user
  validates :user_id, uniqueness: { scope: :platform_resource_id }
  validates :percent, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  before_save { self.completed_at = percent == 100 ? (completed_at || Time.current) : nil if will_save_change_to_percent? }
end
