class AchievementDefinition < ApplicationRecord
  KINDS=%w[course_completion program_completion skill_badge special_recognition certificate other].freeze
  ICONS=%w[trophy star code book users rocket certificate graduation target laptop].freeze
  COLORS=%w[purple blue green gold pink].freeze
  has_many :achievement_awards,dependent: :restrict_with_error
  scope :active, -> {where(is_active:true)}
  validates :title,presence:true,length:{maximum:200}
  validates :description,:criteria,length:{maximum:2000}
  validates :kind,inclusion:{in:KINDS}
  validates :icon,inclusion:{in:ICONS}
  validates :color,inclusion:{in:COLORS}
end
