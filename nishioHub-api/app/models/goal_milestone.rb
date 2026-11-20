class GoalMilestone < ApplicationRecord
  belongs_to :mentee_goal,optional:true
  belongs_to :mentor_goal,optional:true
  belongs_to :program_goal,optional:true
  validates :title,presence:true,length:{maximum:200}
  validates :completed,inclusion:{in:[true,false]}
  validate do
    errors.add(:base,'Choose exactly one goal') unless [mentee_goal_id,mentor_goal_id,program_goal_id].compact.size==1
    raw=target_date_before_type_cast
    valid=raw.blank?||raw.is_a?(Date)||raw.is_a?(Time)||raw.is_a?(String)&&raw.match?(/\A\d{4}-\d{2}-\d{2}\z/)&&(Date.iso8601(raw) rescue nil)
    errors.add(:target_date,'must be a valid ISO date') unless valid
  end
end
