class AchievementNote < ApplicationRecord
  belongs_to :author,class_name:'User',optional:true
  scope :active, ->{where(is_active:true)}
  validates :body,presence:true,length:{maximum:2000}
  validates :author_name,presence:true,length:{maximum:200}
  validate {errors.add(:achievement_key,'is invalid') unless AchievementIdentity.valid?(achievement_key)}
end
