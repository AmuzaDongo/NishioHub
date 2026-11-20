class AdminUserSerializer
  def initialize(user, actor:)
    @user, @actor = user, actor
  end

  def as_json(*)
    roles = @user.effective_roles
    editable = @user.id != @actor.id && (!@user.platform_admin? || @actor.super_admin?)
    { id: @user.id, full_name: @user.full_name, email: @user.email, phone_number: @user.phone_number,
      affiliation: @user.affiliation, avatar: @user.avatar_url, is_active: @user.is_active?, is_verified: @user.is_verified?,
      primary_role_id: @user.role_id, roles: roles.map { |role| RoleSerializer.new(role).as_json },
      created_at: @user.created_at&.iso8601, last_active_at: @user.last_active_at&.iso8601, lock_version: @user.lock_version,
      capabilities: { update: editable && @actor.management_permission?('users.update'),
        status: editable && @actor.management_permission?('users.status'),
        password: editable && @actor.management_permission?('users.password'),
        sessions: editable && @actor.management_permission?('users.sessions') } }
  end
end
