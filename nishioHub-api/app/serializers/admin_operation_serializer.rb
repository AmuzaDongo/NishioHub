class AdminOperationSerializer
  def initialize(record, actor:)
    @record, @actor = record, actor
  end
  def as_json(*)
    item = @record
    base = { id: item.id, created_at: item.created_at.iso8601 }
    case item
    when PlatformProgram
      base.merge(kind: 'program', banner_url: item.banner_url, banner_filename: item.banner.attached? ? item.banner.filename.to_s : nil, title: item.title, description: item.description, status: item.status,
        starts_on: item.starts_on&.iso8601, ends_on: item.ends_on&.iso8601,
        member_count: item.program_memberships.active.count, session_count: item.bookings.count,
        lock_version: item.lock_version)
    when Booking
      base.merge(kind: 'session', title: item.service.title, description: "#{item.mentor.full_name} with #{item.mentee.full_name}", status: item.status,
        scheduled_at: item.scheduled_at.iso8601, duration: item.duration, updated_at: item.updated_at.iso8601(6),
        mentor: { id: item.mentor_id, name: item.mentor.full_name }, mentee: { id: item.mentee_id, name: item.mentee.full_name },
        program: item.platform_program && { id: item.platform_program_id, title: item.platform_program.title },
        can_complete: item.status == 'confirmed' && item.scheduled_at + item.duration.minutes <= Time.current)
    when Event
      base.merge(kind: 'event', title: item.title, description: item.description, status: item.status != 'published' ? item.status : item.ends_at < Time.current ? 'ended' : 'upcoming',
        starts_at: item.starts_at.iso8601, ends_at: item.ends_at.iso8601, category: item.category, location: item.location,
        meeting_url: @actor.management_permission?('dashboard.manage') ? item.meeting_url : nil, capacity: item.capacity,
        registrations: item.event_registrations.where(status: 'registered').count, updated_at: item.updated_at.iso8601(6))
    when PlatformResource
      file = item.file.attached? ? { filename: item.file.filename.to_s, byte_size: item.file.byte_size, download_path: "/admin/dashboard/resources/#{item.id}/file" } : nil
      base.merge(kind: 'resource', title: item.title, description: item.description, status: item.published? ? 'published' : 'draft',
        published: item.published?, url: item.url, file: file, platform_program_id: item.platform_program_id,
        program: item.platform_program && { id: item.platform_program_id, title: item.platform_program.title }, lock_version: item.lock_version)
    end
  end
end
