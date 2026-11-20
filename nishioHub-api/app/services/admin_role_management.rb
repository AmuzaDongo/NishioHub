module AdminRoleManagement
  def self.save!(actor, data, role: nil)
    creating = role.nil?
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, 'roles.manage')
      role ||= Role.new
      role.lock! unless creating
      attributes = data.slice('name', 'description', 'permissions')
      if attributes.key?('name') && !attributes['name'].to_s.match?(/\A[a-z][a-z0-9_]{1,49}\z/)
        raise Administration::Rejected.new('Role names must use 2–50 lowercase letters, numbers or underscores', :unprocessable_entity)
      end
      if creating && attributes['name'].to_s.gsub('_', '').in?(Role::BUILT_INS)
        raise Administration::Rejected.new('Built-in role names are reserved', :unprocessable_entity)
      end
      Administration.manage_role!(actor, role, attributes)
      AdminUserManagement.revision!(role, data['lock_version']) unless creating
      before = creating ? {} : role.attributes.slice('name', 'description', 'permissions')
      role.assign_attributes(attributes)
      role.permissions ||= [] if creating
      role.save!
      if !creating && before['permissions'] != role.permissions
        affected = User.where(AdminUserQuery.role_condition([role.id]))
        affected.update_all('auth_version = auth_version + 1, lock_version = lock_version + 1')
        RefreshToken.where(user_id: affected.select(:id)).update_all(revoked: true)
      end
      after = role.attributes.slice('name', 'description', 'permissions')
      changes = after.each_with_object({}) { |(key, value), memo| memo[key] = { before: before[key], after: value } unless value == before[key] }
      Administration.audit!(actor, creating ? 'role.created' : 'role.updated', role, changes) if changes.any?
      role
    end
  end

  def self.destroy!(actor, role, version)
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, 'roles.manage')
      role.lock!
      AdminUserManagement.revision!(role, version)
      Administration.manage_role!(actor, role)
      raise Administration::Rejected.new('Built-in roles cannot be deleted', :unprocessable_entity) if role.builtin?
      if role.users.exists? || role.user_role_assignments.exists?
        raise Administration::Rejected.new('Remove this role from all users before deleting it', :unprocessable_entity)
      end
      Administration.audit!(actor, 'role.deleted', role, { name: role.name })
      role.destroy!
    end
  end
end
