module AdminSessionManagement
  def self.authorize!(actor)
    actor.reload
    Administration.authorize!(actor, 'dashboard.read')
    Administration.authorize!(actor, 'dashboard.manage')
  end
  def self.revision!(booking, version)
    unless version.is_a?(String) && version == booking.updated_at.iso8601(6)
      raise Administration::Rejected.new('This session changed. Reload it before saving.', :conflict)
    end
  end
  def self.validate!(data, booking: nil)
    raise Administration::Rejected.new('New mentorship bookings are paused', :forbidden) unless SystemSetting.config['matching_enabled']
    starts = Time.iso8601(data['scheduled_at'].to_s) rescue nil
    unless starts && starts > Time.current && data['scheduled_at'].to_s.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
      raise Administration::Rejected.new('Choose a future date and time with an explicit timezone', :unprocessable_entity)
    end
    duration = data['duration'].to_s.match?(/\A\d+\z/) ? data['duration'].to_i : 0
    raise Administration::Rejected.new('Sessions must last 15–240 minutes', :unprocessable_entity) unless duration.between?(15, 240)
    ids = AdminProgramManagement.ids!(data['mentee_ids'])
    mentor = User.with_role('mentor').where(is_active: true).find(AdminMenteeQuery.positive_id!(data['mentor_id']))
    mentees = User.with_role('mentee').where(id: ids, is_active: true)
    unless mentees.count == ids.size && !ids.include?(mentor.id) && mentor.mentor_profile&.accepting_bookings != false
      raise Administration::Rejected.new('Choose active mentees and a different mentor accepting bookings', :unprocessable_entity)
    end
    category = Category.active.find(AdminMenteeQuery.positive_id!(data['category_id']))
    program = PlatformProgram.active.find(AdminMenteeQuery.positive_id!(data['program_id'])) if data['program_id'].present?
    if program && program.program_memberships.active.where(user_id: ids).count != ids.size
      raise Administration::Rejected.new('Enroll every attendee in this program before scheduling', :unprocessable_entity)
    end
    if program
      zone = SystemSetting.config['timezone']
      first = starts.in_time_zone(zone).to_date
      last = (starts + duration.minutes).in_time_zone(zone).to_date
      if program.starts_on && first < program.starts_on || program.ends_on && last > program.ends_on
        raise Administration::Rejected.new('Choose a session within the program dates', :unprocessable_entity)
      end
    end
    attrs = { session_title: data['title'], session_description: data['description'], mentor: mentor, mentee_id: ids.first,
      platform_program: program, session_category: category, duration: duration, scheduled_at: starts, format: data['format'].presence || 'online',
      location: data['location'], meeting_url: data['meeting_url'] }
    sample = Booking.new(attrs.merge(service: Service.new(mentor: mentor, category: category, title: data['title'], description: data['description'].presence || 'Administrator scheduled session', duration: duration, price: 0), status: 'confirmed', total_price: 0))
    sample.service.validate!
    sample.validate!
    if sample.format == 'on_site' && sample.location.blank?
      raise Administration::Rejected.new('Enter a location for on-site sessions', :unprocessable_entity)
    end
    if BookingSchedule.conflict?(mentor_id: mentor.id, mentee_ids: ids, starts_at: starts, duration: duration, except_id: booking&.id)
      raise Administration::Rejected.new('A mentor or attendee already has a session at this time', :unprocessable_entity)
    end
    { attrs: attrs, ids: ids, category: category }
  end
  def self.save!(actor, data, booking: nil)
    creating = booking.nil?
    Administration.transaction do
      authorize!(actor)
      booking.lock! if booking
      revision!(booking, data['updated_at']) if booking
      if booking && (!%w[pending confirmed].include?(booking.status) || booking.scheduled_at <= Time.current)
        raise Administration::Rejected.new('Only future pending or confirmed sessions can be edited', :unprocessable_entity)
      end
      # Use the same user locks as ordinary bookings, then recheck eligibility and overlaps.
      ids = AdminProgramManagement.ids!(data['mentee_ids'])
      User.where(id: ids + [data['mentor_id'].to_i]).order(:id).lock.load
      valid = validate!(data, booking: booking)
      if booking
        if booking.total_price.positive? && (booking.mentor_id != valid[:attrs][:mentor].id || booking.mentee_id != valid[:ids].first || booking.booking_participants.pluck(:user_id).sort != valid[:ids].sort)
          raise Administration::Rejected.new('Keep the original mentor and attendees for a paid booking', :unprocessable_entity)
        end
        if booking.mentor_id != valid[:attrs][:mentor].id
          valid[:attrs][:service] = Service.create!(mentor: valid[:attrs][:mentor], category: valid[:category], title: data['title'], description: data['description'].presence || 'Administrator scheduled session', duration: valid[:attrs][:duration], price: 0, is_active: false, tags: [])
        end
        booking.update!(valid[:attrs])
      else
        service = Service.create!(mentor: valid[:attrs][:mentor], category: valid[:category], title: data['title'], description: data['description'].presence || 'Administrator scheduled session', duration: valid[:attrs][:duration], price: 0, is_active: false, tags: [])
        booking = Booking.create!(valid[:attrs].merge(service: service, total_price: 0, status: 'confirmed', payment_status: 'pending', skip_participant_notifications: true))
      end
      booking.booking_participants.where.not(user_id: valid[:ids]).destroy_all
      valid[:ids].each { |id| booking.booking_participants.find_or_create_by!(user_id: id) }
      booking.skip_participant_notifications = false
      booking.touch
      NotifyBookingParticipants.call(booking, revision: creating ? nil : booking.updated_at.iso8601(6))
      Administration.audit!(actor, 'session.saved', booking, data.except('updated_at'))
      booking.reload
    end
  end
  def self.status!(actor, booking, value, version)
    Administration.transaction do
      authorize!(actor); booking.lock!; revision!(booking, version)
      allowed = booking.status == 'pending' ? %w[confirmed cancelled] : booking.status == 'confirmed' ? %w[completed cancelled] : []
      raise Administration::Rejected.new('This session cannot move to that status', :unprocessable_entity) unless allowed.include?(value)
      if value == 'completed' && booking.scheduled_at + booking.duration.minutes > Time.current
        raise Administration::Rejected.new('Complete the session after its scheduled end', :unprocessable_entity)
      end
      booking.update!(status: value)
      Administration.audit!(actor, 'session.status_updated', booking, { status: value })
      booking
    end
  end
  def self.attendance!(actor, booking, participant_id, value, version)
    Administration.transaction do
      authorize!(actor); booking.lock!; revision!(booking, version)
      unless [true, false, nil].include?(value) && %w[confirmed completed].include?(booking.status) && booking.scheduled_at <= Time.current
        raise Administration::Rejected.new('Record attendance once a confirmed session has started', :unprocessable_entity)
      end
      participant = booking.booking_participants.find(participant_id)
      participant.update!(attended: value, recorded_at: value.nil? ? nil : Time.current)
      booking.touch
      Administration.audit!(actor, 'session.attendance_updated', booking, { user_id: participant.user_id, attended: value })
    end
  end
end
