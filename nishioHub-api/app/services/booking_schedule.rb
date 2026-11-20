module BookingSchedule
  def self.conflict?(mentor_id:, starts_at:, duration:, mentee_id: nil, mentee_ids: nil, except_id: nil)
    people = [mentor_id, *(mentee_ids || [mentee_id])].compact.uniq
    scope = Booking.where(status: %w[pending confirmed]).where(
      'mentor_id IN (:people) OR mentee_id IN (:people) OR id IN (SELECT booking_id FROM booking_participants WHERE user_id IN (:people))', people: people)
    scope = scope.where.not(id: except_id) if except_id
    scope.where('scheduled_at < ? AND scheduled_at + duration * INTERVAL \'1 minute\' > ?', starts_at + duration.minutes, starts_at).exists?
  end
end
