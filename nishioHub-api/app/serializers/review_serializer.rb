class ReviewSerializer
  def initialize(review)
    @review = review
  end

  def as_json(*)
    mentee = @review.mentee

    {
      id: @review.id,
      bookingId: @review.booking_id,
      booking_id: @review.booking_id,
      serviceId: @review.service_id,
      service_id: @review.service_id,
      mentorId: @review.mentor_id,
      mentor_id: @review.mentor_id,
      menteeId: @review.mentee_id,
      mentee_id: @review.mentee_id,
      userId: @review.mentee_id,
      user_id: @review.mentee_id,
      rating: @review.rating,
      comment: @review.comment,
      content: @review.comment,
      title: "Review by #{mentee&.full_name}",
      date: @review.created_at&.strftime("%B %d, %Y"),
      createdAt: @review.created_at&.iso8601,
      created_at: @review.created_at&.iso8601,
      mentee: {
        id: mentee&.id,
        name: mentee&.full_name,
        full_name: mentee&.full_name,
        avatar: mentee&.profile&.profile_picture
      }
    }
  end
end
