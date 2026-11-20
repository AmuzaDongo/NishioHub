class MentorGoal < ApplicationRecord
  include ManagedGoal
  belongs_to :user
  belongs_to :platform_program,optional:true
  has_many :goal_milestones,dependent: :destroy
  has_many :goal_progress_events,dependent: :destroy
end
