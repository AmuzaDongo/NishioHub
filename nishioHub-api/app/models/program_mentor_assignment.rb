class ProgramMentorAssignment < ApplicationRecord
  belongs_to :platform_program
  belongs_to :user
  validates :user_id, uniqueness: { scope: :platform_program_id }
  validates :is_active, inclusion: { in: [true, false] }
  scope :active, -> { where(is_active: true) }
end
