class NotifyBookingParticipants
  def self.call(booking, revision: nil)
    title = { "pending" => "Mentorship Booking Requested", "confirmed" => "Mentorship Session Confirmed",
      "completed" => "Mentorship Session Completed", "cancelled" => "Mentorship Session Cancelled" }.fetch(booking.status)
    title = 'Mentorship Session Updated' if revision
    participants = User.where(id: booking.booking_participants.select(:user_id)).to_a
    participants << booking.mentee unless participants.any? { |u| u.id == booking.mentee_id }
    recipients = participants.map { |u| [u, booking.mentor.full_name] } + [[booking.mentor, participants.size == 1 ? booking.mentee.full_name : "#{participants.size} learners"]]
    recipients.each do |user, other_name|
      Notification.deliver(user: user, source_key: "booking-#{booking.id}-#{booking.status}#{revision ? "-#{revision}" : ''}", title: title,
        message: "#{booking.session_title || booking.service.title} with #{other_name} is #{booking.status}. Starts #{booking.scheduled_at.in_time_zone(SystemSetting.config['timezone']).strftime('%b %d, %Y %H:%M %Z')}.", category: "mentorship",
        topic: "mentorship", icon: "users", href: "/bookings")
    end
  end
end
