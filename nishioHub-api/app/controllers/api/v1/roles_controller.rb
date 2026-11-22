class Api::V1::RolesController < ApplicationController
  before_action :require_admin!, except: :mentor_mentee

  def mentor_mentee
    render json: Role.in_order_of(:name, %w[mentor mentee]).map { |role| RoleSerializer.new(role).as_json }
  end

  def index
    Administration.authorize!(current_user, 'roles.read')
    roles = Role.order(:id)
    return render_error('No roles found.', :not_found) if roles.empty?
    render json: roles.map { |role| RoleSerializer.new(role).as_json }
  end

  def create
    Administration.authorize!(current_user, 'roles.manage')
    name = role_params[:name].to_s
    return render_error("Role '#{name}' already exists.", :bad_request) if Role.exists?(name: name)
    role = AdminRoleManagement.save!(current_user, role_params.to_h)
    render json: RoleSerializer.new(role).as_json, status: :created
  end

  def update
    role = Role.find_by(id: params[:id])
    return render_error("Role with ID #{params[:id]} not found.", :not_found) unless role
    role = AdminRoleManagement.save!(current_user, role_params.to_h, role: role)
    render json: RoleSerializer.new(role).as_json
  end

  def destroy
    Administration.authorize!(current_user, 'roles.manage')
    role = Role.find_by(id: params[:id])
    return render_error("Role with ID #{params[:id]} not found.", :not_found) unless role
    return render_error('Built-in roles cannot be deleted', :unprocessable_entity) if role.builtin?
    AdminRoleManagement.destroy!(current_user, role, params[:lock_version])
    render json: { detail: 'Role deleted' }
  end

  private

  def role_params
    source = params[:role].present? ? params.require(:role) : params
    source.permit(:name, :description, :lock_version, permissions: [])
  end
end
