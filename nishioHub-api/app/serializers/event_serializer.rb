class EventSerializer
  def initialize(event, user:, registration: nil)
    @event = event
    @user = user
    @registration = registration
  end

  def as_json(*)
    registered_count = @event.event_registrations.count { |registration| registration.status == "registered" }
    {
      id: @event.id, title: @event.title, description: @event.description,
      category: @event.category, status: @event.status, display_status: @event.display_status, event_type: @event.event_type, starts_at: @event.starts_at.iso8601, ends_at: @event.ends_at.iso8601,
      location: @event.location, image: @event.image_path, capacity: @event.capacity,
      available_places: @event.capacity && [@event.capacity - registered_count, 0].max,
      organizer: { id: @event.organizer_id, name: @event.organizer.full_name },
      can_manage: @user.platform_admin? ? @user.management_permission?("dashboard.manage") : @event.organizer_id == @user.id,
      meeting_url: ((@registration&.status == "registered" && @event.status == "published") || @event.organizer_id == @user.id) ? @event.meeting_url : nil,
      registration: @registration&.as_json(only: %i[id status attended_at reminder_minutes])
    }
  end
end
