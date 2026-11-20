class GoalUpdate < ApplicationRecord
  include GoalOwned
  validates :body,presence:true,length:{maximum:2000}
end
