class EventRegistration < ApplicationRecord
  attr_accessor :attendance_explicit
  validates :user_id, uniqueness: { scope: :event_id }
  validates :attendance_status, inclusion: { in: %w[unrecorded present absent] }
  before_validation { self.attendance_status = attended_at ? 'present' : 'unrecorded' if !attendance_explicit && will_save_change_to_attended_at? }
  REMINDER_MINUTES = [0, 15, 30, 60, 1440].freeze
  belongs_to :event
  belongs_to :user
  after_save :notify_registration_changes
  validates :status, inclusion: { in: %w[registered cancelled] }
  validates :reminder_minutes, inclusion: { in: REMINDER_MINUTES }
  private

  def notify_registration_changes
    if (previously_new_record? || saved_change_to_status?) && status == "registered"
      Notification.deliver(user: user, source_key: "event-registration-#{id}", title: "Event Registration Confirmed",
        message: "You're registered for “#{event.title}”. View the event for details and calendar reminders.",
        category: "events", topic: "events", icon: "calendar", href: "/events?event=#{event_id}")
    end
    if saved_change_to_attended_at? && attended_at
      Notification.deliver(user: user, source_key: "event-attendance-#{id}", title: "Event Attendance Confirmed",
        message: "Your attendance at “#{event.title}” was confirmed by the organizer.", category: "events",
        topic: "events", icon: "calendar", href: "/my-achievements")
    end
  end
end
