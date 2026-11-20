class MenteeActivityFeed
  def initialize(user)
    @user = user
  end

  def entries
    (learning_entries + booking_entries + goal_entries + event_entries).sort_by { |entry| [entry[:occurred_at], entry[:id]] }.reverse
  end

  private

  def learning_entries
    @user.learning_enrollments.includes(:learning_lesson_completions).flat_map do |enrollment|
      course = LearningCatalog.find(enrollment.course_key)
      next [] unless course

      completed = (course["lessons"].map { |lesson| lesson["id"] } - enrollment.completed_lesson_ids).empty?
      snapshot = {
        id: "course-#{enrollment.id}", category: "learning", icon: completed ? "book" : "play",
        title: "#{completed ? 'Completed' : 'In Progress'}: #{course['title']}",
        description: "#{enrollment.completed_lesson_ids.size} of #{course['lessons'].size} lessons completed. Course last updated.",
        status: completed ? "completed" : "in_progress", occurred_at: enrollment.updated_at.iso8601,
        href: "/learning-area?course=#{course['id']}"
      }
      lessons = enrollment.learning_lesson_completions.filter_map do |completion|
        lesson = course["lessons"].find { |candidate| candidate["id"] == completion.lesson_key }
        next unless lesson

        { id: "lesson-#{completion.id}", category: "learning", icon: "laptop",
          title: "Completed: #{lesson['title']}", description: "You finished a lesson in #{course['title']}.",
          status: "completed", occurred_at: completion.created_at.iso8601,
          href: "/learning-area?course=#{course['id']}&lesson=#{lesson['id']}" }
      end
      [snapshot, *lessons]
    end
  end

  def booking_entries
    @user.mentee_bookings.includes(:service, :mentor).map do |booking|
      status = if booking.status.in?(%w[completed cancelled])
        booking.status
      elsif booking.scheduled_at >= Time.current
        "upcoming"
      else
        "in_progress"
      end
      title = case booking.status
              when "completed" then "Attended Mentorship Session"
              when "cancelled" then "Cancelled Mentorship Session"
              when "pending" then "Requested Mentorship Session"
              else "Mentorship Session"
              end
      {
        id: "booking-#{booking.id}", category: "mentorship", icon: "users", title: title,
        description: "#{booking.service.title} with #{booking.mentor.full_name}#{booking.status == 'pending' ? ' · awaiting confirmation' : ''}.",
        status: status, occurred_at: (booking.status.in?(%w[completed cancelled]) ? booking.updated_at : booking.scheduled_at).iso8601,
        href: "/bookings"
      }
    end
  end

  def event_entries
    @user.event_registrations.includes(:event).map do |registration|
      event = registration.event
      status = if event.status == "cancelled" || registration.status == "cancelled"
        "cancelled"
      elsif registration.attended_at
        "completed"
      elsif event.starts_at > Time.current
        "upcoming"
      else
        "in_progress"
      end
      {
        id: "event-#{registration.id}", category: event.category == "challenge" ? "challenges" : "events",
        icon: event.category == "challenge" ? "trophy" : "calendar",
        title: "#{registration.attended_at ? 'Attended' : (event.status == 'cancelled' || registration.status == 'cancelled') ? 'Cancelled' : 'Registered'}: #{event.title}",
        description: "#{event.location}#{event.ends_at < Time.current && !registration.attended_at ? ' · attendance not recorded' : ''}",
        status: status, occurred_at: (registration.attended_at || event.starts_at).iso8601, href: "/events?event=#{event.id}"
      }
    end
  end

  def goal_entries
    GoalProgressEvent.joins(:mentee_goal).where(mentee_goals: { user_id: @user.id, archived_at: nil }).includes(:mentee_goal).map do |event|
      {
        id: "goal-#{event.id}", category: "learning", icon: "target",
        title: "#{event.note}: #{event.mentee_goal.title}",
        description: "Learning goal progress recorded at #{event.progress}%.",
        status: event.progress == 100 ? "completed" : "in_progress", occurred_at: event.created_at.iso8601,
        href: "/my-goals"
      }
    end
  end
end
