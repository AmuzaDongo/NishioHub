class AdminEventQuery
  def initialize(params = {})
    @params = params; @now = Time.current; @zone = SystemSetting.config['timezone']
  end
  def filtered(day: true)
    scope = Event.kept.left_joins(:platform_program)
    if @params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.first(150))}%"
      scope = scope.where('events.title ILIKE :q OR events.description ILIKE :q OR events.location ILIKE :q OR platform_programs.title ILIKE :q', q: term)
    end
    if @params[:type].present? && @params[:type] != 'all'
      raise Administration::Rejected.new('Invalid event type', :unprocessable_entity) unless Event::EVENT_TYPES.include?(@params[:type])
      scope = scope.where(event_type: @params[:type])
    end
    %i[tab status].each { |key| scope = status_scope(scope, @params[key]) if @params[key].present? && @params[key] != 'all' }
    scope = scope.where(platform_program_id: AdminMenteeQuery.positive_id!(@params[:program_id])) if @params[:program_id].present?
    if day && @params[:day].present?
      date = Date.iso8601(@params[:day]) rescue nil
      raise Administration::Rejected.new('Choose a valid calendar date', :unprocessable_entity) unless date && date.iso8601 == @params[:day]
      start = date.in_time_zone(@zone); scope = scope.where('events.starts_at < ? AND events.ends_at > ?', start + 1.day, start)
    end
    scope
  end
  def status_scope(scope, value)
    case value
    when 'scheduled', 'draft' then scope.where(status: 'draft')
    when 'cancelled' then scope.where(status: 'cancelled')
    when 'completed' then scope.where(status: 'published').where('events.ends_at <= ?', @now)
    when 'ongoing' then scope.where(status: 'published').where('events.starts_at <= ? AND events.ends_at > ?', @now, @now)
    when 'upcoming' then scope.where(status: 'published').where('events.starts_at > ?', @now)
    else raise Administration::Rejected.new('Invalid event status', :unprocessable_entity)
    end
  end
  def ordered(scope = filtered)
    column = {'date'=>'events.starts_at','title'=>'events.title','attendees'=>"(SELECT COUNT(*) FROM event_registrations r WHERE r.event_id=events.id AND r.status='registered')"}[@params[:sort].presence || 'date']
    direction = @params[:direction].presence || 'asc'
    raise Administration::Rejected.new('Invalid event sorting', :unprocessable_entity) unless column && %w[asc desc].include?(direction)
    scope.order(Arel.sql("#{column} #{direction.upcase}, events.id ASC"))
  end
  def self.rows(scope)
    events = scope.includes(:platform_program, :organizer).with_attached_banner.to_a
    counts = EventRegistration.where(event_id: events.map(&:id), status: 'registered').group(:event_id).count
    present = EventRegistration.where(event_id: events.map(&:id), status: 'registered', attendance_status: 'present').group(:event_id).count
    events.map do |e|
      {id:e.id, title:e.title, description:e.description, event_type:e.event_type, status:e.status, display_status:e.display_status,
       format:e.format, target_audiences:e.target_audiences, public_featured:e.public_featured, public_details:e.public_details, public_recording_url:e.public_recording_url, location:e.location, meeting_url:e.meeting_url, capacity:e.capacity, starts_at:e.starts_at.iso8601, ends_at:e.ends_at.iso8601,
       program:e.platform_program && {id:e.platform_program_id,title:e.platform_program.title}, organizer:{id:e.organizer_id,name:e.organizer.full_name},
       attendees:counts.fetch(e.id,0), attended:present.fetch(e.id,0), image:e.image_path, lock_version:e.lock_version}
    end
  end
  def report
    counts = Event.kept.group(:event_type).count
    types = %w[webinar workshop conference networking launch]
    distribution = types.map { |type| {type:type,count:counts.fetch(type,0)} }
    distribution << {type:'other',count:counts.except(*types).values.sum}
    now = @now; active = EventRegistration.joins(:event).where(status:'registered').where(events:{deleted_at:nil}).where.not(events:{status:'cancelled'})
    metrics = {total:Event.kept.count,completed:status_scope(Event.kept.all,'completed').count,upcoming:status_scope(Event.kept.all,'upcoming').count,attendees:active.count}
    changes = {total:delta(Event.kept.all,:created_at),completed:delta(status_scope(Event.kept.all,'completed'),:ends_at),attendees:delta(active,:created_at),upcoming:nil}
    month = @params[:month].presence || now.in_time_zone(@zone).strftime('%Y-%m')
    date = Date.strptime(month,'%Y-%m') rescue nil
    raise Administration::Rejected.new('Choose a valid calendar month',:unprocessable_entity) unless date && date.strftime('%Y-%m')==month
    first = date.beginning_of_month.beginning_of_week(:monday); last = first + 42.days
    calendar_scope = filtered(day:false).where('events.starts_at < ? AND events.ends_at > ?',last.in_time_zone(@zone),first.in_time_zone(@zone))
    calendar = self.class.rows(calendar_scope.order(:starts_at).limit(500)).map do |e|
      e.slice(:id,:title,:starts_at,:ends_at,:display_status).merge(first_day:Time.iso8601(e[:starts_at]).in_time_zone(@zone).to_date.iso8601,last_day:(Time.iso8601(e[:ends_at])-0.000001).in_time_zone(@zone).to_date.iso8601)
    end
    {stats:metrics.merge(changes:changes),distribution:distribution,next_event:self.class.rows(status_scope(Event.kept.all,'upcoming').order(:starts_at).limit(1)).first,
     calendar:{month:month,first_day:first.iso8601,events:calendar,truncated:calendar_scope.count>500}}
  end
  def delta(scope, column)
    table = scope.klass.table_name
    AdminReportingPeriod.change(scope.where("#{table}.#{column} >= ? AND #{table}.#{column} <= ?",@now-30.days,@now).count,scope.where("#{table}.#{column} >= ? AND #{table}.#{column} < ?",@now-60.days,@now-30.days).count)
  end
end
