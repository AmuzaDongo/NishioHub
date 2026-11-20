class ProgramMembership < ApplicationRecord
  validates :progress, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  before_save do
    self.completed_at = progress == 100 ? (completed_at || Time.current) : nil if will_save_change_to_progress?
  end
  belongs_to :platform_program
  validate :capacity_available
  def capacity_available
    return unless is_active? && (new_record? || will_save_change_to_is_active?) && user&.has_role?('mentee') && platform_program&.capacity
    enrolled = platform_program.program_memberships.where(is_active: true, user_id: User.with_role('mentee').select(:id))
    enrolled = enrolled.where.not(id: id) if persisted?
    errors.add(:base, 'Program capacity would be exceeded') if enrolled.count >= platform_program.capacity
  end
  belongs_to :user
  validates :user_id, uniqueness: { scope: :platform_program_id }
  validates :is_active, inclusion: { in: [true, false] }
  scope :active, -> { where(is_active: true) }
end
