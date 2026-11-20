class MentorSerializer
  def initialize(user, include_details: false)
    @user = user
    @include_details = include_details
  end

  def as_json(*)
    profile = @user.mentor_profile
    user_profile = @user.profile
    services = @user.services.select(&:is_active)
    reviews = @user.mentor_reviews
    rating = reviews.empty? ? nil : (reviews.sum(&:rating).to_f / reviews.size).round(1)
    avatar_url = profile&.avatar&.attached? ? profile.avatar.url : nil
    legacy_picture = user_profile&.profile_picture
    avatar = avatar_url || (@user.avatar.attached? ? @user.avatar_url : legacy_picture)

    payload = {
      id: @user.id,
      name: @user.full_name,
      full_name: @user.full_name,
      avatar: avatar,
      avatar_url: avatar_url,
      profile_picture: avatar,
      bio: @user.bio.nil? ? (profile&.bio.presence || user_profile&.bio) : @user.bio,
      headline: profile&.title,
      currency: profile&.currency,
      timezone: profile&.timezone,
      role: "mentor",
      role_name: "mentor",
      role_id: @user.role_id,
      title: profile&.title,
      isVerified: profile&.is_verified,
      is_verified: profile&.is_verified,
      location: @user.location || [user_profile&.city, user_profile&.country].compact.join(", "),
      yearsOfExperience: profile&.years_of_experience,
      years_of_experience: profile&.years_of_experience,
      skills: profile ? profile.skills.map(&:name) : [],
      languages: profile&.languages || [],
      education: profile&.education || [],
      experience: profile&.experience || [],
      hourlyRate: profile&.hourly_rate&.to_f,
      hourly_rate: profile&.hourly_rate&.to_f,
      rating: rating,
      reviewCount: reviews.size,
      review_count: reviews.size,
      acceptingBookings: profile&.accepting_bookings,
      accepting_bookings: profile&.accepting_bookings,
      joinedAt: @user.created_at&.iso8601,
      joined_at: @user.created_at&.iso8601
    }

    if @include_details
      payload[:services] = services.map { |service| ServiceSerializer.new(service).as_json }
      payload[:reviews] = reviews.sort_by(&:created_at).reverse.map { |review| ReviewSerializer.new(review).as_json }
      payload[:availability] = @user.availability_slots.available.order(:starts_at).map do |slot|
        AvailabilitySlotSerializer.new(slot).as_json
      end
    end

    payload
  end
end
