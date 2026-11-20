class AdminMenteeTimeline
  def initialize(user)
    @user = user
  end
  def interactions
    # Aggregate metadata only. Administrator read access does not reveal chat bodies.
    conversations = ConversationMembership.where(user_id: @user.id).select(:conversation_id)
    mentors = User.with_role('mentor').where.not(id: @user.id).select(:id)
    mentor_conversations = ConversationMembership.where(conversation_id: conversations, user_id: mentors).select(:conversation_id)
    scope = ChatMessage.where(conversation_id: mentor_conversations)
    scope.where(sender_id: @user.id).or(scope.where(sender_id: mentors))
  end
  def sql
    id = @user.id.to_i
    sources = [
      Booking.joins(:service).where(mentee_id: id).select("'session-' || bookings.id AS id, 'session' AS kind, 'Mentorship session ' || bookings.status AS title, services.title AS description, CASE WHEN bookings.status IN ('completed','cancelled') THEN bookings.updated_at ELSE bookings.created_at END AS occurred_at"),
      LearningLessonCompletion.joins(:learning_enrollment).where(learning_enrollments: { user_id: id }).select("'lesson-' || learning_lesson_completions.id AS id, 'learning' AS kind, 'Learning lesson completed' AS title, learning_enrollments.course_key || ': ' || learning_lesson_completions.lesson_key AS description, learning_lesson_completions.created_at AS occurred_at"),
      GoalProgressEvent.joins(:mentee_goal).where(mentee_goals: { user_id: id, archived_at: nil }).select("'goal-' || goal_progress_events.id AS id, 'goal' AS kind, goal_progress_events.note AS title, mentee_goals.title AS description, goal_progress_events.created_at AS occurred_at"),
      EventRegistration.joins(:event).where(user_id: id).select("'event-' || event_registrations.id AS id, 'event' AS kind, 'Event registration ' || event_registrations.status AS title, events.title AS description, event_registrations.created_at AS occurred_at"),
      PlatformResourceAccess.joins(:platform_resource).where(user_id: id).select("'resource-' || platform_resource_accesses.id AS id, 'resource' AS kind, 'Resource ' || platform_resource_accesses.kind AS title, platform_resources.title AS description, platform_resource_accesses.created_at AS occurred_at"),
      interactions.select("'interaction-' || chat_messages.id AS id, 'interaction' AS kind, 'Mentor interaction' AS title, 'Message activity with a mentor (content private)' AS description, chat_messages.created_at AS occurred_at"),
      AdministrationAudit.where(target_type: 'User', target_id: id).select("'admin-' || administration_audits.id AS id, 'administration' AS kind, REPLACE(administration_audits.action, '.', ' ') AS title, administration_audits.actor_name || ' updated this account' AS description, administration_audits.created_at AS occurred_at")
    ]
    "(#{sources.map(&:to_sql).join(' UNION ALL ')}) AS mentee_activity"
  end
  def page(page, query = '')
    conn = ApplicationRecord.connection
    term = conn.quote("%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.first(150))}%")
    filter = query.present? ? "WHERE title ILIKE #{term} OR description ILIKE #{term}" : ''
    count = conn.select_value("SELECT COUNT(*) FROM #{sql} #{filter}").to_i
    rows = conn.select_all("SELECT * FROM #{sql} #{filter} ORDER BY occurred_at DESC, id DESC LIMIT 20 OFFSET #{(page - 1) * 20}").to_a
    { items: rows.map { |row| row.merge('occurred_at' => row['occurred_at'].to_time.iso8601) }, meta: { page: page, total: count, total_pages: (count / 20.0).ceil, per_page: 20 } }
  end
  def engagement
    zone = ActiveSupport::TimeZone[SystemSetting.config['timezone']]
    today = Time.current.in_time_zone(zone).to_date
    joined = @user.created_at.in_time_zone(zone).to_date
    days = [[(today - joined).to_i + 1, 1].max, 30].min
    start = (today - (days - 1)).in_time_zone(zone).beginning_of_day
    conn = ApplicationRecord.connection
    tz = conn.quote(zone.tzinfo.name)
    # Administrative changes do not count as learner engagement.
    dates = conn.select_values("SELECT DISTINCT DATE(occurred_at AT TIME ZONE 'UTC' AT TIME ZONE #{tz}) FROM #{sql} WHERE kind <> 'administration' AND occurred_at >= #{conn.quote(start)} AND occurred_at <= #{conn.quote(Time.current)}").map(&:to_date)
    dates << @user.last_active_at.in_time_zone(zone).to_date if @user.last_active_at && @user.last_active_at.between?(start, Time.current)
    active_days = dates.uniq.size
    { percent: [(active_days * 100.0 / days).round, 100].min, active_days: active_days, days: days }
  end
end
