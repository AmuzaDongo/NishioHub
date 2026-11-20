class LearningEnrollment < ApplicationRecord
  belongs_to :user
  has_many :learning_lesson_completions, dependent: :destroy
  has_one :learning_certificate, dependent: :destroy
  after_save :record_lesson_completions, if: :saved_change_to_completed_lesson_ids?
  after_save :issue_certificate_if_complete
  validates :course_key, presence: true, uniqueness: { scope: :user_id }
  validate :course_exists

  def course_complete?
    course = LearningCatalog.find(course_key)
    course && (course["lessons"].map { |lesson| lesson["id"] } - completed_lesson_ids).empty?
  end

  def issue_certificate_if_complete
    create_learning_certificate! unless learning_certificate || !course_complete?
  end

  private

  def record_lesson_completions
    previous = Array(completed_lesson_ids_before_last_save)
    added = completed_lesson_ids - previous
    known = LearningCatalog.find(course_key).fetch("lessons").map { |lesson| lesson["id"] }
    (added & known).each do |key|
      learning_lesson_completions.find_or_create_by!(lesson_key: key)
    end
  end

  def course_exists
    errors.add(:course_key, "is unknown") unless LearningCatalog.find(course_key)
  end
end
