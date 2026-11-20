class LearningCertificate < ApplicationRecord
  belongs_to :learning_enrollment
  before_validation :assign_identity, on: :create
  after_create :notify_course_completion
  validates :identifier, :issued_at, presence: true

  private

  def notify_course_completion
    course = LearningCatalog.find(learning_enrollment.course_key)
    Notification.deliver(user: learning_enrollment.user, source_key: "certificate-#{id}", title: "Course Completed!",
      message: "Congratulations! You completed all lessons in “#{course['title']}”. Your certificate is ready.",
      category: "learning", topic: "learning", icon: "graduation", href: "/my-achievements")
  end

  def assign_identity
    self.identifier ||= SecureRandom.uuid
    self.issued_at ||= Time.current
  end
end
