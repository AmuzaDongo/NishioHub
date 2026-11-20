module AdminMenteeManagement
  def self.find!(id) = User.with_role('mentee').find(id)
  def self.profile_revision!(profile, value)
    expected = profile&.lock_version || 0
    unless value.to_s.match?(/\A\d+\z/) && value.to_i == expected
      raise Administration::Rejected.new('This mentee profile changed. Reload before saving.', :conflict)
    end
  end
  def self.apply_status!(actor, user, profile, status)
    raise Administration::Rejected.new('Choose a valid mentee status', :unprocessable_entity) unless AdminMenteeQuery::STATES.include?(status)
    Administration.authorize!(actor, 'users.status')
    Administration.manage_user!(actor, user)
    active = status.in?(%w[active graduated])
    Administration.ensure_super_admin_remains!(user, roles: user.effective_roles, active: active)
    if user.is_active? != active
      user.update!(is_active: active, auth_version: user.auth_version + 1)
      user.refresh_tokens.update_all(revoked: true)
    end
    profile.management_status = status
  end
  def self.save!(actor, data, target: nil)
    creating = target.nil?
    result = nil
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, creating ? 'users.create' : 'users.update')
      target ||= User.new
      unless creating
        target.lock!
        Administration.manage_user!(actor, target)
        AdminUserManagement.revision!(target, data['lock_version'])
      end
      profile = creating ? nil : target.mentee_profile
      profile&.lock!
      profile_revision!(profile, data['profile_version']) unless creating
      account = data.slice('full_name', 'email', 'phone_number', 'password', 'lock_version')
      if creating
        role = Role.all.find { |item| item.canonical_name == 'mentee' }
        raise Administration::Rejected.new('Configure the Mentee role first', :unprocessable_entity) unless role
        account.merge!('role_ids' => [role.id], 'primary_role_id' => role.id, 'is_active' => true, 'is_verified' => false)
      end
      target = AdminUserManagement.save!(actor, account, target: creating ? nil : target)
      profile ||= target.build_mentee_profile
      before = profile.attributes.slice('management_status', 'assigned_mentor_id', 'primary_program_id', 'school', 'grade', 'location', 'education', 'interests', 'bio')
      profile.assign_attributes(data.slice('school', 'grade', 'location', 'education', 'interests', 'bio'))
      if data.key?('status')
        old_state = user_state(target, profile)
        apply_status!(actor, target, profile, data['status']) unless data['status'] == old_state
      end
      if data.key?('mentor_id')
        mentor = User.with_role('mentor').where(is_active: true).find(data['mentor_id']) if data['mentor_id'].present?
        raise Administration::Rejected.new('Mentee and assigned mentor must be different people', :unprocessable_entity) if mentor&.id == target.id
        profile.assigned_mentor = mentor
      end
      if data.key?('program_id')
        program = PlatformProgram.active.find(data['program_id']) if data['program_id'].present?
        previous_id = profile.primary_program_id
        if previous_id && previous_id != program&.id
          ProgramMembership.where(user_id: target.id, platform_program_id: previous_id).update_all(is_active: false, updated_at: Time.current)
        end
        profile.primary_program = program
        program.program_memberships.find_or_initialize_by(user: target).update!(is_active: true) if program
      end
      profile.save!
      # Profile-only writes must also invalidate a displayed account revision.
      target.touch
      after = profile.reload.attributes.slice(*before.keys)
      Administration.audit!(actor, creating ? 'mentee.created' : 'mentee.updated', target, { before: before, after: after })
      result = target.reload
    end
    result
  end
  def self.user_state(user, profile)
    return profile.management_status == 'suspended' ? 'suspended' : 'inactive' unless user.is_active?
    profile.management_status == 'graduated' ? 'graduated' : 'active'
  end
  def self.status!(actor, target, data)
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, 'users.status')
      target.lock!
      AdminUserManagement.revision!(target, data['lock_version'])
      profile = target.mentee_profile
      profile&.lock!
      profile_revision!(profile, data['profile_version'])
      profile ||= target.build_mentee_profile
      apply_status!(actor, target, profile, data['status'])
      profile.save!
      target.touch
      Administration.audit!(actor, 'mentee.status_changed', target, { status: data['status'] })
      target.reload
    end
  end
end
