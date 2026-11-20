module Administration
  PERMISSIONS = {
    'dashboard.read' => 'View the platform dashboard and operational records', 'dashboard.manage' => 'Manage programs, sessions, events and platform resources',
    'users.read' => 'View users and account details', 'users.create' => 'Create users',
    'users.update' => 'Edit users and role assignments', 'users.status' => 'Activate or deactivate users',
    'users.password' => 'Reset user passwords', 'users.sessions' => 'Revoke user sessions', 'users.import' => 'Import users from CSV',
    'users.export' => 'Export users to CSV', 'roles.read' => 'View roles and permissions',
    'roles.manage' => 'Create and manage custom roles', 'system.manage' => 'Manage system settings'
  }.freeze
  class Rejected < StandardError
    attr_reader :status
    def initialize(message, status = :forbidden)
      @status = status
      super(message)
    end
  end

  def self.authorize!(actor, permission)
    raise Rejected, 'Administrator access required' unless actor.platform_admin?
    raise Rejected, "You do not have permission to #{PERMISSIONS.fetch(permission).downcase}" unless actor.management_permission?(permission)
  end

  # All staff/role changes take the same row lock, so concurrent operations cannot
  # defeat the protected-role and last-super-admin checks.
  def self.transaction(&block)
    SystemSetting.current.with_lock(&block)
  end

  def self.audit!(actor, action, target, changeset)
    AdministrationAudit.create!(actor: actor, actor_name: actor.full_name, action: action,
      target_type: target.class.name, target_id: target.id, changeset: changeset)
  end

  def self.manage_user!(actor, target)
    raise Rejected, 'Use My Account Settings to edit your own account' if actor.id == target.id
    raise Rejected, 'Only a Super Admin can change administrator accounts' if target.platform_admin? && !actor.super_admin?
  end

  def self.check_roles!(actor, roles)
    raise Rejected.new('Select at least one valid role', :unprocessable_entity) if roles.empty?
    if roles.any?(&:administrative?) && !actor.super_admin?
      raise Rejected, 'Only a Super Admin can assign Admin or Super Admin roles'
    end
  end

  def self.ensure_super_admin_remains!(target, roles:, active:)
    saved = User.includes(:role, :additional_roles).find(target.id)
    return unless saved.is_active? && saved.platform_admin?
    other_staff = User.where(is_active: true).where.not(id: target.id).includes(:role, :additional_roles).to_a
    if (!active || !roles.any?(&:administrative?)) && !other_staff.any?(&:platform_admin?)
      raise Rejected.new('At least one active administrator must remain', :unprocessable_entity)
    end
    if saved.super_admin? && (!active || !roles.any? { |role| role.canonical_name == 'superadmin' }) && !other_staff.any?(&:super_admin?)
      raise Rejected.new('At least one active Super Admin must remain', :unprocessable_entity)
    end
  end

  def self.manage_role!(actor, role, attributes = {})
    if role.canonical_name == 'superadmin'
      raise Rejected, 'The Super Admin role is protected'
    end
    if role.administrative? && !actor.super_admin?
      raise Rejected, 'Only a Super Admin can change administrator permissions'
    end
    if attributes.key?('permissions')
      requested = attributes['permissions']
      if requested.is_a?(Array) && requested.any? { |permission| !actor.management_permission?(permission) }
        raise Rejected, 'You cannot grant permissions you do not hold'
      end
      if role.builtin? && !role.administrative? && requested.present?
        raise Rejected.new('Member roles do not grant administrative permissions', :unprocessable_entity)
      end
    end
  end
end
