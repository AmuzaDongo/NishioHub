class AdminProgramQuery
  def initialize(params = {})
    @params = params
    @mentees = User.with_role('mentee').select(:id)
  end
  def enrolled_sql(active: true)
    "SELECT pm.* FROM program_memberships pm WHERE pm.platform_program_id = platform_programs.id AND pm.user_id IN (#{@mentees.to_sql})#{active ? ' AND pm.is_active' : ''}"
  end
  def count_sql = "(SELECT COUNT(*) FROM (#{enrolled_sql}) enrolled)"
  def progress_sql = "(SELECT COALESCE(AVG(progress), 0) FROM (#{enrolled_sql}) enrolled)"
  def rating_sql = "(SELECT AVG(reviews.rating) FROM reviews JOIN bookings ON bookings.id = reviews.booking_id WHERE bookings.platform_program_id = platform_programs.id AND bookings.status = 'completed')"
  def filtered
    scope = PlatformProgram.all
    if @params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.strip.first(150))}%"
      scope = scope.where(<<~SQL.squish, term: term)
        platform_programs.title ILIKE :term OR platform_programs.description ILIKE :term
        OR EXISTS (SELECT 1 FROM program_mentor_assignments pma JOIN users u ON u.id = pma.user_id WHERE pma.platform_program_id = platform_programs.id AND pma.is_active AND u.full_name ILIKE :term)
        OR EXISTS (SELECT 1 FROM program_memberships pm JOIN users u ON u.id = pm.user_id WHERE pm.platform_program_id = platform_programs.id AND pm.is_active AND u.full_name ILIKE :term)
        OR EXISTS (SELECT 1 FROM platform_resources pr WHERE pr.platform_program_id = platform_programs.id AND pr.title ILIKE :term)
      SQL
    end
    %i[tab status].each do |key|
      value = @params[key]
      next if value.blank? || value == 'all'
      raise Administration::Rejected.new('Invalid program status', :unprocessable_entity) unless %w[active draft archived ongoing].include?(value)
      if value == 'ongoing'
        scope = scope.where(status: 'active').where('starts_on <= ? AND (ends_on IS NULL OR ends_on >= ?)', today, today)
      else
        scope = scope.where(status: value)
      end
    end
    if @params[:category_id].present?
      scope = @params[:category_id] == 'none' ? scope.where(category_id: nil) : scope.where(category_id: id!(@params[:category_id]))
    end
    scope = scope.where(id: ProgramMentorAssignment.active.where(user_id: id!(@params[:mentor_id])).select(:platform_program_id)) if @params[:mentor_id].present?
    scope = scope.where("#{rating_sql} IS NOT NULL") if @params[:rated_only] == 'true'
    scope
  end
  def ordered(scope = filtered)
    expression = { 'name' => 'platform_programs.title', 'enrolled' => count_sql, 'rating' => rating_sql, 'start' => 'platform_programs.starts_on', 'created' => 'platform_programs.created_at' }[@params[:sort].presence || 'created']
    direction = @params[:direction].presence || 'desc'
    raise Administration::Rejected.new('Invalid program sorting', :unprocessable_entity) unless expression && %w[asc desc].include?(direction)
    scope.order(Arel.sql("#{expression} #{direction.upcase} NULLS LAST, platform_programs.id ASC"))
  end
  def rows(scope)
    programs = scope.select('platform_programs.*', "#{count_sql} AS enrolled_count", "#{progress_sql} AS progress_value", "#{rating_sql} AS rating_value").includes(:category).with_attached_banner.to_a
    assignments = ProgramMentorAssignment.active.where(platform_program_id: programs.map(&:id)).includes(user: [:profile, :mentor_profile, avatar_attachment: :blob]).group_by(&:platform_program_id)
    programs.map do |program|
      { audience_stages: program.audience_stages, themes: program.themes, featured: program.featured, id: program.id, title: program.title, description: program.description, icon: program.icon, banner_url: program.banner_url, banner_filename: program.banner.attached? ? program.banner.filename.to_s : nil, category: program.category && { id: program.category_id, name: program.category.name },
        mentors: assignments.fetch(program.id, []).map { |assignment| { id: assignment.user_id, name: assignment.user.full_name, avatar: assignment.user.avatar_url, active: assignment.user.is_active? } },
        enrolled: program[:enrolled_count].to_i, progress: program[:progress_value].to_f.round, rating: program[:rating_value]&.to_f&.round(1), status: program.status,
        display_status: program.status == 'active' && program.starts_on && program.starts_on <= today && (!program.ends_on || program.ends_on >= today) ? 'ongoing' : program.status,
        starts_on: program.starts_on&.iso8601, ends_on: program.ends_on&.iso8601, lock_version: program.lock_version }
    end
  end
  def report
    zone = ActiveSupport::TimeZone[SystemSetting.config['timezone']]
    now = Time.current.in_time_zone(zone)
    month = now.beginning_of_month
    months = (@params[:months].presence || '6').to_s
    raise Administration::Rejected.new('Choose 3, 6 or 12 months', :unprocessable_entity) unless %w[3 6 12].include?(months)
    n = months.to_i
    # Lifetime distinct learner/program enrollment records, including withdrawn ones.
    enrollments = ProgramMembership.where(user_id: @mentees)
    current = enrollments.where(is_active: true)
    total = PlatformProgram.count
    enrolled = enrollments.count
    participants = User.where(id: current.select(:user_id), is_active: true).where('last_active_at >= ?', 30.days.ago).count
    reviews = Review.joins(:booking).where(bookings: { status: 'completed' }).where.not(bookings: { platform_program_id: nil })
    distribution = PlatformProgram.group(:category_id).count
    names = Category.where(id: distribution.keys.compact).pluck(:id, :name).to_h
    segments = distribution.sort_by { |id, count| [-count, id || 0] }.map { |id, count| { id: id, name: names[id] || 'Uncategorized', count: count } }
    segments = segments.first(5) + [{ id: 'other', name: 'Other Categories', count: segments.drop(5).sum { |s| s[:count] } }] if segments.size > 6
    trend = (n - 1).downto(0).map { |offset| start = month - offset.months; { month: start.to_date.iso8601, enrollments: enrollments.where('created_at < ?', [start + 1.month, now].min).count } }
    { stats: { total: total, enrollments: enrolled, active_participants: participants, rating: reviews.average(:rating)&.to_f&.round(1), review_count: reviews.count,
        program_change: AdminReportingPeriod.change(total, PlatformProgram.where('created_at < ?', month).count), enrollment_change: AdminReportingPeriod.change(enrolled, enrollments.where('created_at < ?', month).count) },
      distribution: segments, trend: trend, trend_change: AdminReportingPeriod.change(enrolled, enrollments.where('created_at < ?', month - (n - 1).months).count),
      months: n, timezone: zone.tzinfo.name, top_programs: rows(PlatformProgram.active.where("#{rating_sql} IS NOT NULL").order(Arel.sql("#{rating_sql} DESC, #{count_sql} DESC, platform_programs.id ASC")).limit(3)) }
  end
  private
  def today = Time.current.in_time_zone(SystemSetting.config['timezone']).to_date
  def id!(value) = AdminMenteeQuery.positive_id!(value)
end
