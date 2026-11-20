class AvailabilitySlotSerializer
  def initialize(slot)
    @slot = slot
  end

  def as_json(*)
    {
      id: @slot.id,
      mentorId: @slot.mentor_id,
      mentor_id: @slot.mentor_id,
      startsAt: @slot.starts_at&.iso8601,
      starts_at: @slot.starts_at&.iso8601,
      endsAt: @slot.ends_at&.iso8601,
      ends_at: @slot.ends_at&.iso8601,
      isBooked: @slot.is_booked,
      is_booked: @slot.is_booked
    }
  end
end
