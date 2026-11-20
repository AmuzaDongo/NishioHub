module GoalOwned
  extend ActiveSupport::Concern
  included do
    belongs_to :mentee_goal,optional:true
    belongs_to :mentor_goal,optional:true
    belongs_to :program_goal,optional:true
    belongs_to :author,class_name:'User',optional:true
    scope :active, -> {where(is_active:true)}
    validates :author_name,presence:true,length:{maximum:100}
    validate {errors.add(:base,'Choose exactly one goal') unless [mentee_goal_id,mentor_goal_id,program_goal_id].compact.size==1}
  end
  def goal = mentee_goal||mentor_goal||program_goal
end
