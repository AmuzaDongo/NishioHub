class SystemSettingAudit < ApplicationRecord
  belongs_to :actor, class_name: 'User', optional: true
  validates :actor_name, :action, :revision, presence: true
end
