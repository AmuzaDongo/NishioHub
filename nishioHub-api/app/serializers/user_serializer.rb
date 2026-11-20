class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      full_name: @user.full_name,
      email: @user.email,
      bio: @user.bio || @user.mentee_profile&.bio || @user.mentor_profile&.bio || @user.profile&.bio,
      school: @user.mentee_profile&.school,
      location: @user.location || [@user.profile&.city, @user.profile&.country].compact.join(", ").presence, website: @user.website, joinedAt: @user.created_at&.iso8601,
      phone_number: @user.phone_number,
      avatar: @user.avatar_url,
      is_active: @user.is_active,
      roles: @user.effective_roles.map { |role| RoleSerializer.new(role).as_json },
      management_permissions: @user.platform_admin? ? Administration::PERMISSIONS.keys.select { |permission| @user.management_permission?(permission) } : [],
      role: @user.role ? RoleSerializer.new(@user.role).as_json : nil
    }
  end
end
