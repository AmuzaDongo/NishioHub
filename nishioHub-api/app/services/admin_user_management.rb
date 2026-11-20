module AdminUserManagement
  FIELDS = %w[full_name email phone_number affiliation is_verified is_active].freeze

  def self.roles_for(data, target = nil)
    return target ? target.effective_roles : [] unless data.key?('role_ids')
    ids = data['role_ids']
    unless ids.is_a?(Array) && ids.size.between?(1, 20) && ids.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      raise Administration::Rejected.new('Choose between 1 and 20 valid roles', :unprocessable_entity)
    end
    roles = Role.where(id: ids.map(&:to_i).uniq).to_a
    raise Administration::Rejected.new('One or more roles do not exist', :unprocessable_entity) unless roles.size == ids.map(&:to_i).uniq.size
    roles
  end

  def self.password_valid!(value)
    minimum = SystemSetting.config['password_min_length']
    unless value.is_a?(String) && value.length >= minimum && value.bytesize <= 72
      raise Administration::Rejected.new("Use at least #{minimum} characters and at most 72 bytes for the password", :unprocessable_entity)
    end
  end

  def self.revision!(user, version)
    unless version.to_s.match?(/\A\d+\z/) && version.to_i == user.lock_version
      raise Administration::Rejected.new('This account changed. Reload the user list before trying again.', :conflict)
    end
  end

  def self.snapshot(user)
    user.attributes.slice(*FIELDS).merge('roles' => user.effective_roles.map(&:name).sort, 'primary_role_id' => user.role_id)
  end

  def self.save!(actor, data, target: nil)
    creating = target.nil?
    permission = creating ? 'users.create' : 'users.update'
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, permission)
      target ||= User.new
      target.lock! unless creating
      unless creating
        Administration.manage_user!(actor, target)
        revision!(target, data['lock_version'])
      end
      roles = roles_for(data, creating ? nil : target)
      Administration.check_roles!(actor, roles)
      primary = data.key?('primary_role_id') ? roles.find { |role| role.id.to_s == data['primary_role_id'].to_s } : (roles.find { |role| role.id == target.role_id } || roles.first)
      raise Administration::Rejected.new('Primary role must be one of the assigned roles', :unprocessable_entity) unless primary
      %w[is_active is_verified].each do |key|
        if data.key?(key) && ![true, false].include?(data[key])
          raise Administration::Rejected.new("#{key} must be true or false", :unprocessable_entity)
        end
      end
      if !creating && data.key?('is_active') && data['is_active'] != target.is_active?
        Administration.authorize!(actor, 'users.status')
      end
      changing_password = creating || data['password'].present?
      if changing_password
        Administration.authorize!(actor, 'users.password') unless creating
        password_valid!(data['password'])
      end
      before = creating ? {} : snapshot(target)
      attributes = data.slice(*FIELDS)
      %w[full_name email phone_number affiliation].each { |key| attributes[key] = attributes[key].to_s.strip if attributes.key?(key) }
      attributes['email'] = attributes['email'].downcase if attributes.key?('email')
      target.assign_attributes(attributes)
      target.is_verified = false if !creating && target.will_save_change_to_email? && !data.key?('is_verified')
      target.role = primary
      roles_changed = creating || before['roles'] != roles.map(&:name).sort || before['primary_role_id'] != primary.id
      sensitive = !creating && (roles_changed || changing_password || target.will_save_change_to_is_active? || target.will_save_change_to_email?)
      target.auth_version += 1 if sensitive
      target.password = data['password'] if changing_password
      Administration.ensure_super_admin_remains!(target, roles: roles, active: target.is_active?) unless creating
      target.save!
      target.additional_roles = roles.reject { |role| role.id == primary.id } if roles_changed
      target.profile&.update!(phone_number: target.phone_number) if attributes.key?('phone_number')
      target.refresh_tokens.update_all(revoked: true) if sensitive
      target.reload
      after = snapshot(target)
      changes = after.each_with_object({}) { |(key, value), memo| memo[key] = { before: before[key], after: value } unless before[key] == value }
      changes['password_changed'] = true if changing_password
      Administration.audit!(actor, creating ? 'user.created' : 'user.updated', target, changes) if changes.any?
      target
    end
  end

  def self.status!(actor, target, active, version)
    raise Administration::Rejected.new('Status must be true or false', :unprocessable_entity) unless [true, false].include?(active)
    Administration.authorize!(actor, 'users.status')
    Administration.manage_user!(actor, target)
    revision!(target, version)
    Administration.ensure_super_admin_remains!(target, roles: target.effective_roles, active: active)
    if target.is_active? != active
      target.update!(is_active: active, auth_version: target.auth_version + 1)
      target.refresh_tokens.update_all(revoked: true)
      Administration.audit!(actor, active ? 'user.activated' : 'user.deactivated', target, {})
    end
    target
  end
end
