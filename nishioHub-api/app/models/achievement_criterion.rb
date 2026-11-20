class AchievementCriterion < ApplicationRecord
  self.table_name='achievement_criteria'
  belongs_to :achievement_award
  CATEGORIES=%w[modules assessments project other].freeze
  validates :title,presence:true,length:{maximum:200}
  validates :category,inclusion:{in:CATEGORIES}
  validates :target_units,numericality:{only_integer:true,greater_than:0,less_than_or_equal_to:100000}
  validates :completed_units,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than_or_equal_to:100000}
  validate {errors.add(:completed_units,'cannot exceed target units') if completed_units&&target_units&&completed_units>target_units}
  before_save do
    self.completed_at=completed_units==target_units ? (completed_at||Time.current) : nil
  end
end
