class AchievementAward < ApplicationRecord
  has_many :achievement_criteria,class_name:'AchievementCriterion',dependent: :destroy
  validates :criteria_snapshot,length:{maximum:2000}
  validates :cohort_label,length:{maximum:150}
  validates :final_score,numericality:{greater_than_or_equal_to:0,less_than_or_equal_to:100},allow_nil:true
  belongs_to :achievement_definition
  belongs_to :user
  belongs_to :platform_program,optional:true
  belongs_to :issuer,class_name:'User',optional:true
  scope :active, -> {where(revoked_at:nil)}
  before_validation(on: :create){self.identifier||=SecureRandom.uuid}
  validates :identifier,presence:true,uniqueness:true
  validates :title,:issuer_name,presence:true,length:{maximum:200}
  validates :description,:revocation_reason,length:{maximum:2000}
  validates :kind,inclusion:{in:AchievementDefinition::KINDS}
  validates :icon,inclusion:{in:AchievementDefinition::ICONS}
  validates :color,inclusion:{in:AchievementDefinition::COLORS}
  validates :awarded_at,presence:true
  validate {errors.add(:awarded_at,'cannot be in the future') if awarded_at&&awarded_at>Time.current}
  validates :revocation_reason,presence:true,if: :revoked_at?
end
