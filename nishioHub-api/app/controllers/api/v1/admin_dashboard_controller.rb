class Api::V1::AdminDashboardController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user, 'dashboard.read') }
  before_action -> { Administration.authorize!(current_user, 'dashboard.manage') }, only: %i[create_program update_program add_members remove_member create_session update_session create_event update_event create_resource update_resource options]
  before_action { response.headers['Cache-Control'] = 'no-store' }

  def show
    render json: AdminDashboardReport.new(current_user, period, params[:q]).call
  end

  def search
    render json: AdminDashboardReport.new(current_user, period, params[:q]).search
  end

  def health
    render json: AdminPlatformHealth.call
  end

  def records
    type = params[:type].to_s
    return render json: AdminActivityFeed.new(period, params[:q]).page(page) if type == 'activities'
    scope = case type
    when 'programs' then PlatformProgram.order(created_at: :desc)
    when 'sessions' then Booking.includes(:service, :mentor, :mentee, :platform_program).order(scheduled_at: :desc)
    when 'events' then Event.kept.includes(:event_registrations).order(starts_at: :desc)
    when 'resources' then PlatformResource.kept.includes(:platform_program, file_attachment: :blob).order(created_at: :desc)
    else return render_error('Choose programs, sessions, events, resources or activities', :unprocessable_entity)
    end
    window = params[:window].presence || 'all'
    return render_error('Choose all, period or upcoming dates', :unprocessable_entity) unless window.in?(%w[all period upcoming])
    if window == 'period'
      column = type == 'sessions' ? :scheduled_at : type == 'events' ? :starts_at : :created_at
      scope = scope.where(column => period.range)
    elsif window == 'upcoming'
      scope = scope.where('scheduled_at >= ?', Time.current).where.not(status: 'cancelled') if type == 'sessions'
      scope = scope.where('ends_at >= ?', Time.current) if type == 'events'
    end
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(150))}%"
      scope = type == 'sessions' ? scope.joins(:service).where('services.title ILIKE ?', term) : scope.where('title ILIKE ? OR description ILIKE ?', term, term)
    end
    if params[:status].present? && params[:status] != 'all'
      allowed = { 'programs' => %w[active draft archived], 'sessions' => Booking::STATUSES, 'resources' => %w[published draft], 'events' => %w[upcoming ended] }
      return render_error('Invalid record status', :unprocessable_entity) unless params[:status].in?(allowed.fetch(type))
      case type
      when 'programs' then scope = scope.where(status: params[:status])
      when 'sessions' then scope = scope.where(status: params[:status])
      when 'resources' then scope = scope.where(published: params[:status] == 'published')
      when 'events' then scope = params[:status] == 'upcoming' ? scope.where('ends_at >= ?', Time.current) : scope.where('ends_at < ?', Time.current)
      end
    end
    count = scope.count
    render json: { items: scope.offset((page - 1) * 20).limit(20).map { |record| serialize(record) }, meta: { page: page, per_page: 20, total: count, total_pages: (count / 20.0).ceil } }
  end

  def record
    klass = { 'programs' => PlatformProgram, 'sessions' => Booking, 'events' => Event.kept, 'resources' => PlatformResource }[params[:type]]
    return render_error('Invalid record type', :unprocessable_entity) unless klass
    render json: serialize(klass.find(params[:id]))
  end

  def options
    people = User.where(is_active: true).where(id: User.with_role('mentor').select(:id)).or(User.where(is_active: true).where(id: User.with_role('mentee').select(:id))).includes(:role, :additional_roles)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
      people = people.where('full_name ILIKE ?', term)
    end
    render json: {
      people: people.order(:full_name).limit(100).map { |user| { id: user.id, name: user.full_name, mentor: user.has_role?('mentor'), mentee: user.has_role?('mentee') } },
      services: Service.active.joins(:mentor).where(users: { is_active: true }).includes(:mentor).order(:title).limit(200).map { |service| { id: service.id, title: service.title, mentor_id: service.mentor_id, mentor_name: service.mentor.full_name, duration: service.duration, price: service.price.to_f } },
      programs: PlatformProgram.active.order(:title).limit(200).as_json(only: %i[id title]),
      categories: Category.active.ordered.as_json(only: %i[id name])
    }
  end

  def create_program
    data = object(:program).permit(:title, :description, :status, :starts_on, :ends_on, :banner, :remove_banner, participant_ids: [])
    participants=data[:participant_ids]&.reject{|value|value==''}
    program = nil
    Administration.transaction do
      reauthorize!
      program = AdminProgramManagement.save!(current_user,data.to_h.except('participant_ids'))
      add_program_members!(program, participants) if participants.present?
    end
    render json: serialize(program), status: :created
  end

  def update_program
    data = object(:program).permit(:title, :description, :status, :starts_on, :ends_on, :lock_version, :banner, :remove_banner)
    program = nil
    Administration.transaction do
      reauthorize!
      program = PlatformProgram.lock.find(params[:id])
      program=AdminProgramManagement.save!(current_user,data.to_h,program:program)
    end
    render json: serialize(program)
  end

  def members
    program = PlatformProgram.find(params[:id])
    scope = program.program_memberships.active.includes(user: [:role, :additional_roles]).order(:id)
    count = scope.count
    render json: { items: scope.offset((page - 1) * 20).limit(20).map { |membership| { id: membership.user_id, name: membership.user.full_name, roles: membership.user.effective_roles.map(&:name), active: membership.user.is_active? } }, meta: { page: page, total: count, total_pages: (count / 20.0).ceil } }
  end

  def add_members
    program = nil
    Administration.transaction do
      reauthorize!
      program = PlatformProgram.lock.find(params[:id])
      add_program_members!(program, params[:user_ids])
      Administration.audit!(current_user, 'program.members_added', program, { count: params[:user_ids].size })
    end
    render json: serialize(program)
  end

  def remove_member
    Administration.transaction do
      reauthorize!
      program = PlatformProgram.lock.find(params[:id])
      program.program_memberships.find_by!(user_id: params[:user_id]).update!(is_active: false)
      program.program_mentor_assignments.where(user_id: params[:user_id]).update_all(is_active: false, updated_at: Time.current)
      program.touch
      Administration.audit!(current_user, 'program.member_removed', program, { user_id: params[:user_id].to_i })
    end
    head :no_content
  end

  def create_session
    return render_error('New mentorship bookings are paused', :forbidden) unless SystemSetting.config['matching_enabled']
    data = object(:session).permit(:service_id, :mentor_id, :mentee_id, :scheduled_at, :platform_program_id, :title, :description, :duration, :price, :category_id)
    starts_at = Time.iso8601(data[:scheduled_at].to_s) rescue nil
    return render_error('Choose a future date and time with an explicit timezone', :unprocessable_entity) unless starts_at && starts_at > Time.current && data[:scheduled_at].to_s.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
    booking = nil
    Administration.transaction do
      reauthorize!
      raise Administration::Rejected, 'New mentorship bookings are paused' unless SystemSetting.config['matching_enabled']
      mentee = User.where(is_active: true).find(data[:mentee_id])
      raise Administration::Rejected.new('Choose an active mentee', :unprocessable_entity) unless mentee.has_role?('mentee')
      service = Service.active.find(data[:service_id]) if data[:service_id].present?
      mentor = service ? service.mentor : User.find(data[:mentor_id])
      User.where(id: [mentor.id, mentee.id]).order(:id).lock.load
      mentor.reload
      mentee.reload
      raise Administration::Rejected.new('Choose an active mentee', :unprocessable_entity) unless mentee.is_active? && mentee.has_role?('mentee')
      unless mentor.is_active? && mentor.has_role?('mentor') && mentor.id != mentee.id && mentor.mentor_profile&.accepting_bookings != false
        raise Administration::Rejected.new('Choose an active mentor accepting sessions, different from the mentee', :unprocessable_entity)
      end
      unless service
        duration = data[:duration].to_s.match?(/\A\d+\z/) ? data[:duration].to_i : 0
        raise Administration::Rejected.new('One-off sessions must last 15–240 minutes', :unprocessable_entity) unless duration.between?(15, 240)
        category = Category.active.find(data[:category_id])
        service = mentor.services.create!(title: data[:title], description: data[:description].presence || 'Private administrator-scheduled session', duration: duration, price: data[:price].presence || 0, category: category, is_active: false, tags: [])
      end
      if BookingSchedule.conflict?(mentor_id: mentor.id, mentee_id: mentee.id, starts_at: starts_at, duration: service.duration)
        raise Administration::Rejected.new('The mentor or mentee already has a session at this time', :unprocessable_entity)
      end
      program = PlatformProgram.active.find(data[:platform_program_id]) if data[:platform_program_id].present?
      if program && !program.program_memberships.active.exists?(user_id: mentee.id)
        raise Administration::Rejected.new('Add the mentee to this program before scheduling its session', :unprocessable_entity)
      end
      booking = Booking.create!(service: service, mentor: mentor, mentee: mentee, scheduled_at: starts_at, duration: service.duration,
        total_price: service.price, status: 'confirmed', payment_status: 'pending', platform_program: program)
      Administration.audit!(current_user, 'session.created', booking, { service_id: service.id, platform_program_id: program&.id })
    end
    render json: serialize(booking), status: :created
  end

  def update_session
    data = object(:session).permit(:status, :updated_at)
    booking = nil
    Administration.transaction do
      reauthorize!
      booking = Booking.lock.find(params[:id])
      timestamp_revision!(booking, data[:updated_at])
      allowed = booking.status == 'pending' ? %w[confirmed cancelled] : booking.status == 'confirmed' ? %w[completed cancelled] : []
      return render_error('This session cannot move to that status', :unprocessable_entity) unless allowed.include?(data[:status])
      if data[:status] == 'completed' && booking.scheduled_at + booking.duration.minutes > Time.current
        return render_error('Complete a session after its scheduled end', :unprocessable_entity)
      end
      booking.update!(status: data[:status])
      Administration.audit!(current_user, 'session.updated', booking, { status: booking.status })
    end
    render json: serialize(booking)
  end

  def create_event
    event = nil
    Administration.transaction do
      reauthorize!
      event = current_user.organized_events.new(object(:event).permit(:title, :description, :category, :starts_at, :ends_at, :location, :meeting_url, :capacity))
      return render_error('Event start must be in the future', :unprocessable_entity) unless event.starts_at && event.starts_at > Time.current
      event.save!
      Administration.audit!(current_user, 'event.created', event, { title: event.title })
    end
    render json: serialize(event), status: :created
  end

  def update_event
    data = object(:event).permit(:title, :description, :category, :starts_at, :ends_at, :location, :meeting_url, :capacity, :updated_at)
    event = nil
    Administration.transaction do
      reauthorize!
      event = Event.kept.lock.find(params[:id])
      return render_error('Cancelled events cannot be edited', :unprocessable_entity) if event.status == 'cancelled'
      timestamp_revision!(event, data[:updated_at])
      attributes = data.except(:updated_at)
      if attributes[:capacity].present? && attributes[:capacity].to_i < event.event_registrations.where(status: 'registered').count
        return render_error('Capacity cannot be lower than current registrations', :unprocessable_entity)
      end
      event.update!(attributes)
      Administration.audit!(current_user, 'event.updated', event, { title: event.title })
    end
    render json: serialize(event)
  end

  def create_resource
    save_resource
  end
  def update_resource
    save_resource(PlatformResource.kept.find(params[:id]))
  end
  def resource_file
    resource = PlatformResource.kept.find(params[:id])
    raise ActiveRecord::RecordNotFound unless resource.file.attached?
    send_data resource.file.download, filename: resource.file.filename.to_s, type: resource.file.content_type, disposition: 'attachment'
  end

  private
  def period = @period ||= AdminReportingPeriod.new(params)
  def page = [[params.fetch(:page, 1).to_i, 1].max, 10000].min
  def serialize(record) = AdminOperationSerializer.new(record, actor: current_user).as_json
  def object(key)
    source = params.require(key)
    raise Administration::Rejected.new("#{key} must be an object", :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source
  end
  def reauthorize!
    current_user.reload
    Administration.authorize!(current_user, 'dashboard.read')
    Administration.authorize!(current_user, 'dashboard.manage')
  end
  def revision!(record, value)
    unless value.to_s.match?(/\A\d+\z/) && value.to_i == record.lock_version
      raise Administration::Rejected.new('This record changed. Reload it before saving.', :conflict)
    end
  end
  def timestamp_revision!(record, value)
    raise Administration::Rejected.new('This record changed. Reload it before saving.', :conflict) unless value == record.updated_at.iso8601(6)
  end
  def add_program_members!(program, raw)
    unless raw.is_a?(Array) && raw.size.between?(1, 100) && raw.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      raise Administration::Rejected.new('Select 1–100 valid members at a time', :unprocessable_entity)
    end
    people = User.where(id: raw.map(&:to_i).uniq, is_active: true).includes(:role, :additional_roles).to_a
    unless people.size == raw.map(&:to_i).uniq.size && people.all? { |user| user.has_role?('mentor') || user.has_role?('mentee') }
      raise Administration::Rejected.new('Choose active mentor or mentee accounts', :unprocessable_entity)
    end
    learners = people.select { |user| user.has_role?('mentee') }.map(&:id)
    current = program.program_memberships.active.where(user_id: User.with_role('mentee').select(:id)).pluck(:user_id)
    if learners.any? && (program.status == 'archived' || program.capacity && (current | learners).size > program.capacity)
      raise Administration::Rejected.new('This program is archived or its capacity would be exceeded', :unprocessable_entity)
    end
    people.each do |user|
      program.program_memberships.find_or_initialize_by(user: user).update!(is_active: true)
      program.program_mentor_assignments.find_or_initialize_by(user: user).update!(is_active: true) if user.has_role?('mentor')
    end
    program.touch
  end
  def save_resource(resource = nil)
    creating = resource.nil?
    data = object(:resource).permit(:title, :description, :url, :published, :platform_program_id, :file, :lock_version)
    file = data.delete(:file)
    if file.present? && (!file.is_a?(ActionDispatch::Http::UploadedFile) || !Marcel::MimeType.for(file.tempfile, name: file.original_filename).in?(PlatformResource::TYPES))
      return render_error('Upload a supported PDF, text file or image', :unprocessable_entity)
    end
    if data.key?(:published)
      value = data[:published]
      unless [true, false, 'true', 'false'].include?(value)
        return render_error('Published must be true or false', :unprocessable_entity)
      end
      data[:published] = [true, 'true'].include?(value)
    end
    Administration.transaction do
      reauthorize!
      resource ||= current_user_platform_resource
      raise ActiveRecord::RecordNotFound if resource.deleted_at
      resource.version_actor = current_user
      ResourceVersion.capture!(resource, current_user) if resource.persisted?
      resource.lock! unless creating
      revision!(resource, data.delete(:lock_version)) unless creating
      data.delete(:lock_version) if creating
      resource.assign_attributes(data)
      resource.file.attach(file) if file.present?
      resource.save!
      Administration.audit!(current_user, creating ? 'resource.created' : 'resource.updated', resource, { title: resource.title, published: resource.published })
    end
    resource.reload
    render json: serialize(resource), status: creating ? :created : :ok
  end
  def current_user_platform_resource = PlatformResource.new(created_by: current_user)
end
