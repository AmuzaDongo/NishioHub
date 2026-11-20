class ProfileSerializer
  def initialize(profile)
    @profile = profile
  end

  def as_json(*)
    {
      id: @profile.id,
      phone_number: @profile.phone_number,
      gender: @profile.gender,
      birth_date: @profile.birth_date&.iso8601,
      address: @profile.address,
      city: @profile.city,
      country: @profile.country,
      profile_picture: @profile.user.avatar.attached? ? @profile.user.avatar_url : @profile.profile_picture,
      bio: @profile.bio,
      user_id: @profile.user_id,
      created_at: @profile.created_at&.iso8601,
    }
  end
end
