class Skill < ApplicationRecord
  has_many :mentor_skills, dependent: :destroy
  has_many :mentor_profiles, through: :mentor_skills

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
end
