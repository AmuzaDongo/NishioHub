class MentorSelfSerializer
  def initialize(profile)
    @profile = profile
    @user = profile.user
  end

  def as_json(*)
    reviews = @user.mentor_reviews
    rating = reviews.empty? ? nil : (reviews.sum(&:rating).to_f / reviews.size).round(1)

    {
      id: @profile.id,
      user_id: @user.id,
      name: @user.full_name,
      headline: @profile.title,
      bio: @profile.bio,
      hourly_rate: @profile.hourly_rate&.to_f,
      currency: @profile.currency,
      languages: @profile.languages || [],
      years_of_experience: @profile.years_of_experience,
      timezone: @profile.timezone,
      skills: @profile.skills.map(&:name),
      services: @profile.user.services.select(&:is_active).map { |service| ServiceSerializer.new(service).as_json },
      availability: @profile.user.availability_slots.available.order(:starts_at).map { |slot| AvailabilitySlotSerializer.new(slot).as_json },
      avatar_url: avatar_url,
      email: @user.email,
      is_verified: @profile.is_verified,
      is_published: @profile.is_published,
      accepting_bookings: @profile.accepting_bookings,
      rating: rating,
      review_count: reviews.size,
      joined_at: @user.created_at&.iso8601,
      created_at: @profile.created_at&.iso8601,
      updated_at: @profile.updated_at&.iso8601,
      is_active: @user.is_active
    }
  end

  private

  def avatar_url
    return @profile.avatar.url if @profile.avatar.attached?
    return @user.avatar_url if @user.avatar.attached?

    nil
  end
end
