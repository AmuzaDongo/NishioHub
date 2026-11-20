class BookingSerializer
  def initialize(booking)
    @booking = booking
  end

  def as_json(*)
    {
      id: @booking.id,
      serviceId: @booking.service_id,
      service_id: @booking.service_id,
      menteeId: @booking.mentee_id,
      mentee_id: @booking.mentee_id,
      mentorId: @booking.mentor_id,
      mentor_id: @booking.mentor_id,
      status: @booking.status,
      scheduledAt: @booking.scheduled_at&.iso8601,
      scheduled_at: @booking.scheduled_at&.iso8601,
      duration: @booking.duration,
      totalPrice: @booking.total_price.to_f,
      total_price: @booking.total_price.to_f,
      paymentStatus: @booking.payment_status,
      payment_status: @booking.payment_status,
      hasReview: @booking.review.present?,
      has_review: @booking.review.present?,
      createdAt: @booking.created_at&.iso8601,
      created_at: @booking.created_at&.iso8601,
      updatedAt: @booking.updated_at&.iso8601,
      updated_at: @booking.updated_at&.iso8601,
      service: ServiceSerializer.new(@booking.service).as_json.merge(title: @booking.session_title || @booking.service.title, description: @booking.session_description || @booking.service.description),
      format: @booking.format, location: @booking.location, meeting_url: @booking.meeting_url,
      mentor: MentorSerializer.new(@booking.mentor).as_json,
      mentee: {
        id: @booking.mentee_id,
        name: @booking.mentee.full_name,
        full_name: @booking.mentee.full_name,
        avatar: @booking.mentee.profile&.profile_picture
      }
    }
  end
end
