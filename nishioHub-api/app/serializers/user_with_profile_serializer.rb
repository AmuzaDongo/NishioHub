class UserWithProfileSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      is_active: @user.is_active,
      full_name: @user.full_name,
      avatar: @user.avatar_url,
      email: @user.email,
      bio: @user.bio || @user.mentee_profile&.bio || @user.mentor_profile&.bio || @user.profile&.bio,
      school: @user.mentee_profile&.school, location: @user.location || [@user.profile&.city, @user.profile&.country].compact.join(", ").presence, website: @user.website, joinedAt: @user.created_at&.iso8601,
      roles: @user.effective_roles.map { |role| RoleSerializer.new(role).as_json },
      role: @user.role ? RoleSerializer.new(@user.role).as_json : nil,
      profile: @user.profile ? ProfileSerializer.new(@user.profile).as_json : nil
    }
  end
end
