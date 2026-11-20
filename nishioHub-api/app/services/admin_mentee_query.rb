class AdminMenteeQuery
  STATES = %w[active inactive graduated suspended].freeze
  STATUS = "CASE WHEN users.is_active IS NOT TRUE THEN CASE WHEN mentee_profiles.management_status = 'suspended' THEN 'suspended' ELSE 'inactive' END WHEN mentee_profiles.management_status = 'graduated' THEN 'graduated' ELSE 'active' END".freeze
  MENTOR = "COALESCE(mentee_profiles.assigned_mentor_id, (SELECT b.mentor_id FROM bookings b WHERE b.mentee_id = users.id AND b.status <> 'cancelled' ORDER BY b.scheduled_at DESC, b.id DESC LIMIT 1))".freeze
  PROGRAM = "(SELECT pm.platform_program_id FROM program_memberships pm WHERE pm.user_id = users.id AND pm.is_active ORDER BY CASE WHEN pm.platform_program_id = mentee_profiles.primary_program_id THEN 0 ELSE 1 END, pm.id LIMIT 1)".freeze
  def self.base = User.with_role('mentee').left_joins(:mentee_profile)
  def self.filtered(params)
    scope = base
    if params[:q].present?
      text = params[:q].to_s.strip.first(150)
      scope = scope.where("users.full_name ILIKE :term OR users.email ILIKE :term OR CAST(users.id AS TEXT) = :id OR EXISTS (SELECT 1 FROM users assigned WHERE assigned.id = #{MENTOR} AND assigned.full_name ILIKE :term) OR EXISTS (SELECT 1 FROM program_memberships pm JOIN platform_programs pp ON pp.id = pm.platform_program_id WHERE pm.user_id = users.id AND pm.is_active AND pp.title ILIKE :term) OR EXISTS (SELECT 1 FROM bookings search_booking JOIN services s ON s.id = search_booking.service_id WHERE search_booking.mentee_id = users.id AND s.title ILIKE :term)", term: "%#{ActiveRecord::Base.sanitize_sql_like(text)}%", id: text.sub(/\ANH-/i, ''))
    end
    %i[tab status].each do |key|
      next if params[key].blank? || params[key] == 'all'
      raise Administration::Rejected.new('Invalid mentee status filter', :unprocessable_entity) unless STATES.include?(params[key])
      scope = scope.where("(#{STATUS}) = ?", params[key])
    end
    if params[:program_id].present?
      id = positive_id!(params[:program_id])
      scope = scope.where(id: ProgramMembership.active.where(platform_program_id: id).select(:user_id))
    end
    scope = scope.where("#{MENTOR} = ?", positive_id!(params[:mentor_id])) if params[:mentor_id].present?
    scope
  end
  def self.positive_id!(value)
    raise Administration::Rejected.new('Invalid filter identifier', :unprocessable_entity) unless value.to_s.match?(/\A[1-9]\d*\z/)
    value.to_i
  end
  def self.ordered(scope, params)
    sort = { 'joined' => 'users.created_at', 'name' => 'users.full_name', 'status' => "(#{STATUS})", 'id' => 'users.id' }[params[:sort].presence || 'joined']
    direction = params[:direction].presence || 'desc'
    raise Administration::Rejected.new('Invalid sort order', :unprocessable_entity) unless sort && direction.in?(%w[asc desc])
    scope.order(Arel.sql("#{sort} #{direction.upcase}, users.id ASC"))
  end
  def self.rows(scope, actor)
    people = scope.select('users.*', "#{STATUS} AS mentee_state", "#{MENTOR} AS selected_mentor_id", "#{PROGRAM} AS selected_program_id").includes(:role, :additional_roles, :mentee_profile, :profile, :mentor_profile, avatar_attachment: :blob).to_a
    ids = people.map(&:id)
    mentors = User.where(id: people.map { |u| u[:selected_mentor_id] }.compact.uniq).includes(:profile, :mentor_profile, avatar_attachment: :blob).index_by(&:id)
    programs = PlatformProgram.where(id: people.map { |u| u[:selected_program_id] }.compact.uniq).index_by(&:id)
    memberships = ProgramMembership.active.where(user_id: ids).includes(:platform_program).group_by(&:user_id)
    progress = MenteeGoal.kept.where(user_id: ids).group(:user_id).average(:progress)
    sessions = Booking.where(mentee_id: ids, status: 'completed').group(:mentee_id).count
    people.map do |user|
      profile = user.mentee_profile
      mentor = mentors[user[:selected_mentor_id]]
      program = programs[user[:selected_program_id]]
      AdminUserSerializer.new(user, actor: actor).as_json.merge(status: user[:mentee_state], progress: progress[user.id]&.to_f&.round || 0,
        completed_sessions: sessions.fetch(user.id, 0), profile_version: profile&.lock_version || 0,
        school: profile&.school, grade: profile&.grade, location: profile&.location, education: profile&.education, interests: profile&.interests || [], bio: profile&.bio || user.profile&.bio,
        mentor: mentor && { id: mentor.id, name: mentor.full_name, avatar: mentor.avatar_url, active: mentor.is_active? },
        program: program && { id: program.id, title: program.title, status: program.status },
        programs: memberships.fetch(user.id, []).map { |membership| { id: membership.platform_program_id, title: membership.platform_program.title } },
        assigned_mentor_id: profile&.assigned_mentor_id, primary_program_id: profile&.primary_program_id)
    end
  end
  def self.report
    scope = base
    zone = ActiveSupport::TimeZone[SystemSetting.config['timezone']]
    now = Time.current.in_time_zone(zone)
    month = now.beginning_of_month
    previous = month - 1.month
    statuses = scope.group(Arel.sql(STATUS)).count
    total = scope.count
    new_count = scope.where('users.created_at >= ?', month).count
    last_new = scope.where(users: { created_at: previous...month }).count
    prior_total = scope.where('users.created_at < ?', month).count
    engaged = scope.where('users.last_active_at >= ?', 30.days.ago).count
    ratings = Review.where(mentee_id: scope.select('users.id'))
    distribution = scope.group(Arel.sql(PROGRAM)).count
    names = PlatformProgram.where(id: distribution.keys.compact).pluck(:id, :title).to_h
    segments = distribution.sort_by { |id, count| [-count, id || 0] }.map { |id, count| { id: id, name: names[id] || 'Unassigned', count: count } }
    if segments.size > 6
      segments = segments.first(5) + [{ id: 'other', name: 'Other Programs', count: segments.drop(5).sum { |item| item[:count] } }]
    end
    growth = 5.downto(0).map do |offset|
      start = month - offset.months
      finish = [start + 1.month, now].min
      { month: start.to_date.iso8601, total: scope.where('users.created_at < ?', finish).count }
    end
    participant_count = scope.where(id: Booking.where(status: 'completed').select(:mentee_id)).count
    goal_count = scope.where(id: MenteeGoal.kept.where(completed: true).select(:user_id)).count
    six_month_baseline = scope.where('users.created_at < ?', month - 5.months).count
    { stats: { total: total, active: statuses.fetch('active', 0), new_this_month: new_count, engaged: engaged,
        engagement_rate: total.zero? ? 0 : (engaged * 100.0 / total).round(1), satisfaction: ratings.average(:rating)&.to_f&.round(1), review_count: ratings.count,
        total_change: AdminReportingPeriod.change(total, prior_total), new_change: AdminReportingPeriod.change(new_count, last_new) },
      statuses: STATES.index_with { |state| statuses.fetch(state, 0) }, distribution: segments, growth: growth,
      growth_change: AdminReportingPeriod.change(total, six_month_baseline), timezone: zone.tzinfo.name,
      engagement: [{ key: 'active', label: 'Active Mentees', count: statuses.fetch('active', 0) }, { key: 'sessions', label: 'Session Participation', count: participant_count },
        { key: 'goals', label: 'Goal Completion', count: goal_count }, { key: 'programs', label: 'Program Completion', count: statuses.fetch('graduated', 0) }] }
  end
end
