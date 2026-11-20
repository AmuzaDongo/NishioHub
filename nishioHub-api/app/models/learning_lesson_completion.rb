class LearningLessonCompletion < ApplicationRecord
  belongs_to :learning_enrollment
  validates :lesson_key, presence: true
end
