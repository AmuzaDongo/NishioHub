class ProgramGoal < ApplicationRecord
  include ManagedGoal
  belongs_to :platform_program
  has_many :goal_milestones,dependent: :destroy
  has_many :goal_progress_events,dependent: :destroy
end
