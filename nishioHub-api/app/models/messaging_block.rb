class MessagingBlock < ApplicationRecord
  belongs_to :blocker,class_name:'User'
  belongs_to :blocked,class_name:'User'
  validates :blocked_id,uniqueness:{scope: :blocker_id}
  validate {errors.add(:blocked,'cannot be yourself') if blocker_id==blocked_id}
  def self.between?(a,b) = where(blocker_id:a,blocked_id:b).or(where(blocker_id:b,blocked_id:a)).exists?
end
