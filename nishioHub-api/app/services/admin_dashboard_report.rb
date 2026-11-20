class AdminDashboardReport
  def initialize(actor, period, query = '')
    @actor, @period, @query = actor, period, query.to_s.first(150).strip
  end

  def call
    users = User.where('created_at < ?', @period.finishes_at)
    summary = AdminUserQuery.summary(users)
    previous_users = users.where('created_at < ?', @period.begins_at)
    metrics = [
      metric('users', users.count, previous_users.count),
      metric('mentors', users.merge(User.with_role('mentor')).count, previous_users.merge(User.with_role('mentor')).count),
      metric('mentees', users.merge(User.with_role('mentee')).count, previous_users.merge(User.with_role('mentee')).count),
      metric('sessions', Booking.where(scheduled_at: @period.range).where.not(status: 'cancelled').count, Booking.where(scheduled_at: @period.previous_range).where.not(status: 'cancelled').count),
      metric('events', Event.kept.where(starts_at: @period.range).count, Event.kept.where(starts_at: @period.previous_range).count)
    ]
    goals = MenteeGoal.kept.where('created_at < ?', @period.finishes_at)
    reviews = Review.joins(:booking).where(bookings: { status: 'completed' }).where(created_at: @period.range)
    current_new = User.where(created_at: @period.range).count
    previous_new = User.where(created_at: @period.previous_range).count
    { period: @period.json, metrics: metrics, growth: growth_series, distribution: summary[:distribution],
      activities: AdminActivityFeed.new(@period, @query).page(1, 5)[:items],
      top_programs: top_programs, upcoming_events: upcoming_events,
      insights: { user_growth: AdminReportingPeriod.change(current_new, previous_new), new_users: current_new, previous_new_users: previous_new,
        goal_completion: goals.exists? ? (goals.where(completed: true).count * 100.0 / goals.count).round(1) : nil, goal_count: goals.count,
        session_rating: reviews.average(:rating)&.to_f&.round(1), review_count: reviews.count },
      capabilities: { view_users: @actor.management_permission?('users.read'), manage: @actor.management_permission?('dashboard.manage'), add_user: @actor.management_permission?('users.read') && @actor.management_permission?('users.create'),
        schedule: @actor.management_permission?('dashboard.manage') && SystemSetting.config['matching_enabled'] }, search_results: search_results }
  end

  def search = search_results

  private
  def metric(key, value, previous)
    { key: key, value: value, previous: previous, change: AdminReportingPeriod.change(value, previous) }
  end

  def growth_series
    zone = ApplicationRecord.connection.quote(@period.zone.tzinfo.name)
    grouped = User.where(created_at: @period.range).group(Arel.sql("DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE #{zone})")).count
    total = User.where('created_at < ?', @period.begins_at).count
    (@period.starts_on..@period.ends_on).map do |day|
      total += grouped.fetch(day, 0)
      { date: day.iso8601, users: total }
    end
  end

  def top_programs
    scope = PlatformProgram.active
    scope = scope.where('title ILIKE ?', term) if @query.present?
    scope.left_joins(:program_memberships).group('platform_programs.id')
      .select('platform_programs.*, COUNT(program_memberships.id) FILTER (WHERE program_memberships.is_active) AS member_count')
      .order(Arel.sql('member_count DESC, platform_programs.title ASC')).limit(5)
      .map { |program| { id: program.id, title: program.title, members: program[:member_count].to_i } }
  end

  def upcoming_events
    scope = Event.kept.where(status: 'published').where('ends_at >= ?', Time.current)
    scope = scope.where('title ILIKE ? OR description ILIKE ?', term, term) if @query.present?
    scope.includes(:event_registrations).order(:starts_at).limit(3).map do |event|
      { id: event.id, title: event.title, starts_at: event.starts_at.iso8601, ends_at: event.ends_at.iso8601,
        registrations: event.event_registrations.count { |registration| registration.status == 'registered' } }
    end
  end

  def term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

  def search_results
    return [] if @query.blank?
    groups = []
    if @actor.management_permission?('users.read')
      groups += User.where('full_name ILIKE ? OR email ILIKE ?', term, term).order(:full_name).limit(5).map { |user| { kind: 'user', id: user.id, title: user.full_name, description: "Account NH-#{user.id}" } }
    end
    groups += PlatformProgram.where('title ILIKE ?', term).order(:title).limit(5).map { |item| { kind: 'program', id: item.id, title: item.title, description: item.status } }
    groups += Booking.joins(:service).where('services.title ILIKE ?', term).includes(:service).order(scheduled_at: :desc).limit(5).map { |item| { kind: 'session', id: item.id, title: item.service.title, description: item.status } }
    groups += Event.kept.where('title ILIKE ?', term).order(starts_at: :desc).limit(5).map { |item| { kind: 'event', id: item.id, title: item.title, description: item.location } }
    groups += PlatformResource.kept.where('title ILIKE ?', term).order(:title).limit(5).map { |item| { kind: 'resource', id: item.id, title: item.title, description: item.published? ? 'Published resource' : 'Draft resource' } }
    groups
  end
end
