class AdminSessionQuery
  def initialize(params = {}) = @params = params
  def self.status_sql
    now = ActiveRecord::Base.connection.quote(Time.current)
    "CASE WHEN bookings.status = 'completed' THEN 'completed' WHEN bookings.status = 'cancelled' THEN 'cancelled' WHEN bookings.status = 'pending' THEN 'scheduled' WHEN bookings.scheduled_at > #{now} THEN 'upcoming' WHEN bookings.scheduled_at + bookings.duration * INTERVAL '1 minute' > #{now} THEN 'ongoing' ELSE 'awaiting_completion' END"
  end
  def filtered
    scope = Booking.joins(:service, :mentor).left_joins(:platform_program)
    if @params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.first(150))}%"
      scope = scope.where('COALESCE(bookings.session_title, services.title) ILIKE :term OR COALESCE(bookings.session_description, services.description) ILIKE :term OR users.full_name ILIKE :term OR platform_programs.title ILIKE :term OR EXISTS (SELECT 1 FROM booking_participants bp JOIN users attendees ON attendees.id = bp.user_id WHERE bp.booking_id = bookings.id AND attendees.full_name ILIKE :term)', term: term)
    end
    %i[tab status].each do |key|
      value = @params[key].presence || 'all'
      next if value == 'all'
      if value == 'upcoming'
        scope = scope.where(status: %w[pending confirmed]).where('scheduled_at > ?', Time.current)
      elsif %w[scheduled ongoing completed cancelled awaiting_completion].include?(value)
        scope = scope.where("#{self.class.status_sql} = ?", value)
      else
        raise Administration::Rejected.new('Invalid session status', :unprocessable_entity)
      end
    end
    %i[program_id mentor_id].each do |key|
      next if @params[key].blank?
      column = key == :program_id ? :platform_program_id : key
      scope = scope.where(column => AdminMenteeQuery.positive_id!(@params[key]))
    end
    if @params[:format].present? && @params[:format] != 'all'
      raise Administration::Rejected.new('Invalid session format', :unprocessable_entity) unless %w[online live on_site].include?(@params[:format])
      scope = scope.where(format: @params[:format])
    end
    scope
  end
  def ordered(scope = filtered)
    column = { 'date' => 'bookings.scheduled_at', 'title' => 'COALESCE(bookings.session_title, services.title)', 'created' => 'bookings.created_at' }[@params[:sort].presence || 'date']
    direction = @params[:direction].presence || 'desc'
    raise Administration::Rejected.new('Invalid session sorting', :unprocessable_entity) unless column && %w[asc desc].include?(direction)
    scope.order(Arel.sql("#{column} #{direction.upcase}, bookings.id DESC"))
  end
  def self.rows(scope)
    bookings = scope.includes(:service, :platform_program, mentor: [:profile, :mentor_profile, avatar_attachment: :blob]).to_a
    counts = BookingParticipant.where(booking_id: bookings.map(&:id)).group(:booking_id, :attended).count
    bookings.map do |b|
      finish = b.scheduled_at + b.duration.minutes
      display = if %w[completed cancelled].include?(b.status) then b.status
        elsif b.status == 'pending' then 'scheduled'
        elsif b.scheduled_at > Time.current then 'upcoming'
        elsif finish > Time.current then 'ongoing'
        else 'awaiting_completion' end
      { id: b.id, title: b.session_title || b.service.title, description: b.session_description || b.service.description,
        program: b.platform_program && { id: b.platform_program_id, title: b.platform_program.title },
        mentor: { id: b.mentor_id, name: b.mentor.full_name, avatar: b.mentor.avatar_url }, category_id: b.session_category_id || b.service.category_id,
        scheduled_at: b.scheduled_at.iso8601, ends_at: finish.iso8601, duration: b.duration, format: b.format,
        status: b.status, display_status: display, attendees: [true, false, nil].sum { |v| counts.fetch([b.id, v], 0) },
        attended: counts.fetch([b.id, true], 0), location: b.location, meeting_url: b.meeting_url,
        updated_at: b.updated_at.iso8601(6), can_edit: %w[pending confirmed].include?(b.status) && b.scheduled_at > Time.current,
        can_complete: b.status == 'confirmed' && finish <= Time.current,
        can_attend: %w[confirmed completed].include?(b.status) && b.scheduled_at <= Time.current }
    end
  end
  def report
    now = Time.current.in_time_zone(SystemSetting.config['timezone']); month = now.beginning_of_month
    count = Booking.count
    distribution = Booking.group(Arel.sql(self.class.status_sql)).count.map { |key, value| { key: key, count: value } }
    registrations = BookingParticipant.joins(:booking).where.not(bookings: { status: 'cancelled' })
    attendance = registrations.where(attended: true)
    months = (@params[:months].presence || '6').to_s
    raise Administration::Rejected.new('Choose 3, 6 or 12 months', :unprocessable_entity) unless %w[3 6 12].include?(months)
    trend = (months.to_i - 1).downto(0).map do |offset|
      start = month - offset.months
      { month: start.to_date.iso8601, attendance: attendance.where(bookings: { scheduled_at: start...[start + 1.month, now].min }).count }
    end
    top = Booking.where.not(platform_program_id: nil).group(:platform_program_id).order(Arel.sql('COUNT(*) DESC')).limit(4).count
    names = PlatformProgram.where(id: top.keys).pluck(:id, :title).to_h
    { stats: { total: count, completed: Booking.where(status: 'completed').count,
        upcoming: Booking.where(status: %w[pending confirmed]).where('scheduled_at > ?', now).count, attendees: registrations.count,
        growth: AdminReportingPeriod.change(Booking.where(created_at: (now - 30.days)..now).count, Booking.where(created_at: (now - 60.days)...(now - 30.days)).count) },
      distribution: distribution, trend: trend, top_programs: top.map { |id, n| { id: id, title: names[id], count: n } },
      trend_change: AdminReportingPeriod.change(trend.sum { |v| v[:attendance] }, attendance.where(bookings: { scheduled_at: (month - (months.to_i * 2 - 1).months)...(month - (months.to_i - 1).months) }).count) }
  end
end
