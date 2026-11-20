class AchievementGoalLink < ApplicationRecord
  belongs_to :mentee_goal
  validates :mentee_goal_id,uniqueness:{scope: :achievement_key}
  validate {errors.add(:achievement_key,'is invalid') unless AchievementIdentity.valid?(achievement_key)}
end
