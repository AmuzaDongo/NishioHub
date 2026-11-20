class SyncUserNotifications
  def initialize(user)
    @user = user
  end

  def call
    mentorship_reminders
    event_reminders
    badges
  end

  private

  def mentorship_reminders
    @user.mentee_bookings.where(status: "confirmed", scheduled_at: Time.current..24.hours.from_now).includes(:mentor).find_each do |booking|
      time = booking.scheduled_at.in_time_zone("Africa/Kampala").strftime("%b %d at %I:%M %p")
      Notification.deliver(user: @user, source_key: "booking-reminder-#{booking.id}-#{booking.scheduled_at.to_i}",
        title: "Mentorship Session Reminder", message: "You have a mentorship session with #{booking.mentor.full_name} on #{time} (Kampala).",
        category: "mentorship", topic: "mentorship", icon: "users", href: "/bookings")
    end
  end

  def event_reminders
    @user.event_registrations.where(status: "registered", attended_at: nil).where("reminder_minutes > 0").includes(:event).find_each do |registration|
      event = registration.event
      next unless event.deleted_at.nil? && event.status == "published" && event.starts_at > Time.current && event.starts_at <= registration.reminder_minutes.minutes.from_now

      time = event.starts_at.in_time_zone("Africa/Kampala").strftime("%b %d at %I:%M %p")
      Notification.deliver(user: @user, source_key: "event-reminder-#{registration.id}-#{event.starts_at.to_i}",
        title: "Upcoming Event: #{event.title}", message: "Your registered event starts on #{time} (Kampala).",
        category: "events", topic: "events", icon: "calendar", href: "/events?event=#{event.id}")
    end
  end

  def badges
    MenteeAchievements.new(@user).badges.select { |badge| badge[:earned] }.each do |badge|
      earned_at = Time.iso8601(badge[:earned_at])
      next if earned_at < 30.days.ago

      Notification.deliver(user: @user, source_key: "badge-#{badge[:id]}", title: "New Badge Earned!",
        message: "You earned the “#{badge[:name]}” badge. Keep up the great work!",
        category: "learning", topic: "goals", icon: "medal", href: "/my-achievements", created_at: earned_at)
    end
  end
end
