class Api::V1::EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event, only: %i[show register cancel_registration update_registration calendar attendees update_attendance]
  before_action :require_organizer!, only: %i[attendees update_attendance]

  def index
    registrations = current_user.event_registrations.joins(:event).where(events: { deleted_at: nil }).includes(event: [:organizer, :event_registrations]).order(created_at: :desc).to_a
    own = registrations.index_by(&:event_id)
    events = Event.kept.where(status: "published").where("ends_at >= ?", Time.current).includes(:organizer, :event_registrations).order(:starts_at).limit(200)
    active = registrations.select { |registration| registration.status == "registered" && registration.event.status != "cancelled" }
    render json: {
      name: current_user.full_name, avatar: current_user.profile&.profile_picture,
      events: events.map { |event| event_json(event, own[event.id]) },
      registrations: registrations.map { |registration| event_json(registration.event, registration) },
      hosted_events: current_user.organized_events.kept.includes(:organizer, :event_registrations).order(starts_at: :desc).map { |event| event_json(event, own[event.id]) },
      suggestions: current_user.event_suggestions.order(created_at: :desc).as_json(only: %i[id title category created_at]),
      summary: { registered: active.size, attended: active.count { |registration| registration.attended_at.present? },
        upcoming: active.count { |registration| registration.attended_at.nil? && registration.event.ends_at >= Time.current } }
    }
  end

  def show
    render json: event_json(@event, current_user.event_registrations.find_by(event: @event))
  end

  def create
    if current_user.platform_admin?
      Administration.authorize!(current_user, "dashboard.read")
      Administration.authorize!(current_user, "dashboard.manage")
    end
    event = current_user.organized_events.new(params.require(:event).permit(:title, :description, :category, :starts_at, :ends_at, :location, :meeting_url, :capacity))
    return render_error("Start time must be in the future", :unprocessable_entity) if event.starts_at && event.starts_at <= Time.current

    event.save!
    render json: event_json(event), status: :created
  end

  def suggest
    suggestion = current_user.event_suggestions.create!(params.require(:suggestion).permit(:title, :description, :category))
    render json: suggestion.as_json(only: %i[id title category created_at]), status: :created
  end

  def register
    return render_error('New event registrations are paused', :forbidden) unless SystemSetting.config['event_registration_enabled']
    registration = nil
    @event.with_lock do
      return render_error("This event is not open for registration", :unprocessable_entity) unless @event.status == "published"
      return render_error("This event has ended", :unprocessable_entity) if @event.ends_at <= Time.current

      registration = current_user.event_registrations.find_by(event: @event)
      unless registration&.status == "registered"
        if @event.capacity && @event.event_registrations.where(status: "registered").count >= @event.capacity
          return render_error("This event is full", :unprocessable_entity)
        end
        registration ||= current_user.event_registrations.new(event: @event)
        registration.attendance_explicit = true
        registration.update!(status: "registered", attended_at: nil, attendance_status: "unrecorded")
      end
    end
    render json: event_json(@event, registration)
  end

  def cancel_registration
    registration = current_user.event_registrations.find_by!(event: @event)
    return render_error("Attended registrations cannot be cancelled", :unprocessable_entity) if registration.attended_at

    @event.with_lock do
      registration.reload
      return render_error("Attended registrations cannot be cancelled", :unprocessable_entity) if registration.attended_at
      registration.update!(status: "cancelled")
    end
    head :no_content
  end

  def update_registration
    return render_error("This event is not published", :unprocessable_entity) unless @event.status == "published"
    registration = current_user.event_registrations.find_by!(event: @event, status: "registered")
    registration.update!(params.require(:registration).permit(:reminder_minutes))
    render json: event_json(@event, registration)
  end

  def calendar
    return render_error("This event is not published", :unprocessable_entity) unless @event.status == "published"
    registration = current_user.event_registrations.find_by!(event: @event, status: "registered")
    send_data EventCalendarDocument.new(registration).render, type: "text/calendar; charset=utf-8",
      disposition: "attachment", filename: "nishiohub-event-#{@event.id}.ics"
  end

  def attendees
    render json: @event.event_registrations.where(status: "registered").includes(:user).order(:created_at).map { |registration| attendee_json(registration) }
  end

  def update_attendance
    return render_error("This event is not published", :unprocessable_entity) unless @event.status == "published"
    return render_error("Attendance can be recorded when the event starts", :unprocessable_entity) if @event.starts_at > Time.current

    registration = @event.event_registrations.find_by!(id: params[:registration_id], status: "registered")
    attended = ActiveModel::Type::Boolean.new.cast(params.require(:registration).require(:attended))
    @event.with_lock do
      return render_error('This event is not published', :unprocessable_entity) unless @event.deleted_at.nil? && @event.status == 'published'
      registration.reload
      return render_error('Registration cancelled', :unprocessable_entity) unless registration.status == 'registered'
      registration.update!(attended_at: attended ? (registration.attended_at || Time.current) : nil)
    end
    render json: attendee_json(registration)
  end

  private

  def set_event
    @event = Event.kept.includes(:organizer, :event_registrations).find(params[:id])
    staff = current_user.platform_admin? && current_user.management_permission?('dashboard.read')
    owner = @event.organizer_id == current_user.id
    previous = @event.status == 'cancelled' && @event.event_registrations.any? { |r| r.user_id == current_user.id }
    raise ActiveRecord::RecordNotFound unless @event.deleted_at.nil? && @event.status == 'published' || staff || owner || previous
  end

  def require_organizer!
    if current_user.platform_admin?
      Administration.authorize!(current_user, 'dashboard.read')
      Administration.authorize!(current_user, 'dashboard.manage') if action_name == 'update_attendance'
      return
    end
    return if @event.organizer_id == current_user.id

    render_error("Event organizer access required", :forbidden)
  end

  def event_json(event, registration = nil)
    EventSerializer.new(event, user: current_user, registration: registration).as_json
  end

  def attendee_json(registration)
    { id: registration.id, name: registration.user.full_name, attended: registration.attended_at.present? }
  end
end
