class Api::V1::AdminRolesController < ApplicationController
  before_action :require_admin!
  before_action { response.headers['Cache-Control'] = 'no-store' }

  def index
    Administration.authorize!(current_user, 'roles.read')
    render json: { roles: Role.order(:id).map { |role| serialize(role) }, permission_catalog: Administration::PERMISSIONS }
  end

  def create
    Administration.authorize!(current_user, 'roles.manage')
    role = AdminRoleManagement.save!(current_user, role_data)
    render json: serialize(role), status: :created
  end

  def update
    Administration.authorize!(current_user, 'roles.manage')
    role = AdminRoleManagement.save!(current_user, role_data, role: Role.find(params[:id]))
    render json: serialize(role)
  end

  def destroy
    Administration.authorize!(current_user, 'roles.manage')
    AdminRoleManagement.destroy!(current_user, Role.find(params[:id]), params[:lock_version])
    head :no_content
  end

  private

  def role_data
    source = params.require(:role)
    raise Administration::Rejected.new('Role must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    data = source.permit(:name, :description, :lock_version, permissions: []).to_h
    # Preserve an explicitly empty array and reject malformed scalar grants.
    if source.key?(:permissions) && !source[:permissions].is_a?(Array)
      raise Administration::Rejected.new('Permissions must be an array', :unprocessable_entity)
    end
    data
  end

  def serialize(role)
    can_manage = current_user.management_permission?('roles.manage') && role.canonical_name != 'superadmin' && (!role.administrative? || current_user.super_admin?)
    count = User.where(AdminUserQuery.role_condition([role.id])).count
    { id: role.id, name: role.name, description: role.description, permissions: role.effective_permissions,
      user_count: count, builtin: role.builtin?, administrative: role.administrative?, lock_version: role.lock_version,
      capabilities: { edit: can_manage, rename: can_manage && !role.builtin?, delete: can_manage && !role.builtin? && count.zero? } }
  end
end
