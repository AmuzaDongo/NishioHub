class AdministrationAudit < ApplicationRecord
  belongs_to :actor, class_name: 'User', optional: true
  validates :actor_name, :action, :target_type, presence: true
end
