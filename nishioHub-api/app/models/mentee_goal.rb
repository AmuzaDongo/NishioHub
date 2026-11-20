class MenteeGoal < ApplicationRecord
  has_many :achievement_goal_links,dependent: :destroy
  include ManagedGoal
  ICONS=%w[target code laptop graduation trophy].freeze
  belongs_to :user
  belongs_to :platform_program,optional:true
  has_many :goal_milestones,dependent: :destroy
  has_many :goal_progress_events,dependent: :destroy
end
