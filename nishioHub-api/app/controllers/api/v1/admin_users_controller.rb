require 'csv'

class Api::V1::AdminUsersController < ApplicationController
  before_action :require_admin!
  before_action { response.headers['Cache-Control'] = 'no-store' }
  rescue_from ActiveRecord::RecordNotUnique, with: -> { render_error('Email or phone number is already registered', :unprocessable_entity) }

  def access
    render json: { permissions: Administration::PERMISSIONS.keys.select { |permission| current_user.management_permission?(permission) },
      super_admin: current_user.super_admin?, permission_catalog: Administration::PERMISSIONS }
  end

  def index
    Administration.authorize!(current_user, 'users.read')
    scope = AdminUserQuery.filtered(params)
    page = [[params.fetch(:page, 1).to_i, 1].max, 100000].min
    per_page = params.fetch(:per_page, 10).to_i
    return render_error('Page size must be 10, 25, 50 or 100', :unprocessable_entity) unless per_page.in?([10, 25, 50, 100])
    total = scope.count
    users = AdminUserQuery.ordered(scope, params).includes(:role, :additional_roles, :profile, :mentor_profile, avatar_attachment: :blob).offset((page - 1) * per_page).limit(per_page)
    render json: { users: users.map { |user| serialize(user) }, roles: Role.order(:id).map { |role| RoleSerializer.new(role).as_json },
      meta: { page: page, per_page: per_page, total: total, total_pages: (total / per_page.to_f).ceil } }.merge(AdminUserQuery.summary)
  end

  def show
    Administration.authorize!(current_user, 'users.read')
    user = User.includes(:role, :additional_roles).find(params[:id])
    render json: { user: serialize(user), history: AdministrationAudit.where(target_type: 'User', target_id: user.id).order(id: :desc).limit(20).as_json(only: %i[id actor_name action changeset created_at]) }
  end

  def create
    Administration.authorize!(current_user, 'users.create')
    user = AdminUserManagement.save!(current_user, user_data)
    render json: serialize(user), status: :created
  end

  def update
    Administration.authorize!(current_user, 'users.update')
    user = AdminUserManagement.save!(current_user, user_data, target: User.find(params[:id]))
    render json: serialize(user)
  end

  def status
    Administration.authorize!(current_user, 'users.status')
    user = nil
    Administration.transaction do
      current_user.reload
      user = User.lock.find(params[:id])
      AdminUserManagement.status!(current_user, user, (params[:account].is_a?(ActionController::Parameters) ? params[:account][:is_active] : nil), params[:lock_version])
    end
    render json: serialize(user)
  end

  def bulk_status
    Administration.authorize!(current_user, 'users.status')
    ids = selected_ids
    versions = params[:versions]
    return render_error('Supply the displayed revision for each selected user', :unprocessable_entity) unless versions.is_a?(ActionController::Parameters)
    active = (params[:account].is_a?(ActionController::Parameters) ? params[:account][:is_active] : nil)
    Administration.transaction do
      current_user.reload
      users = User.where(id: ids).order(:id).lock.to_a
      raise ActiveRecord::RecordNotFound unless users.size == ids.size
      users.each { |user| AdminUserManagement.status!(current_user, user, active, versions[user.id.to_s]) }
    end
    render json: { updated: ids.size }
  end

  def revoke_sessions
    user = nil
    Administration.transaction do
      current_user.reload
      Administration.authorize!(current_user, 'users.sessions')
      user = User.lock.find(params[:id])
      Administration.manage_user!(current_user, user)
      AdminUserManagement.revision!(user, params[:lock_version])
      user.update!(auth_version: user.auth_version + 1)
      user.refresh_tokens.update_all(revoked: true)
      Administration.audit!(current_user, 'user.sessions_revoked', user, {})
    end
    render json: serialize(user)
  end

  def password
    user = nil
    data = params.require(:password_change).permit(:password, :password_confirmation)
    Administration.transaction do
      current_user.reload
      Administration.authorize!(current_user, 'users.password')
      user = User.lock.find(params[:id])
      Administration.manage_user!(current_user, user)
      AdminUserManagement.revision!(user, params[:lock_version])
      AdminUserManagement.password_valid!(data[:password])
      return render_error('Passwords do not match', :unprocessable_entity) unless data[:password] == data[:password_confirmation]
      user.password = data[:password]
      user.auth_version += 1
      user.save!
      user.refresh_tokens.update_all(revoked: true)
      Administration.audit!(current_user, 'user.password_reset', user, { password_changed: true })
    end
    render json: serialize(user)
  end

  def export
    Administration.authorize!(current_user, 'users.export')
    scope = AdminUserQuery.filtered(params)
    scope = scope.where(id: selected_ids) if params[:user_ids].present?
    return render_error('Filter or select at most 10,000 users for export', :unprocessable_entity) if scope.count > 10000
    content = CSV.generate do |csv|
      csv << %w[id full_name email phone_number roles primary_role affiliation status joined_at last_active_at]
      AdminUserQuery.ordered(scope, params).includes(:role, :additional_roles).each do |user|
        csv << [user.id, user.full_name, user.email, user.phone_number, user.effective_roles.map(&:name).join(';'), user.role&.name, user.affiliation, user.is_active? ? 'active' : 'inactive', user.created_at&.iso8601, user.last_active_at&.iso8601].map { |value| AdminUserQuery.csv_cell(value) }
      end
    end
    Administration.audit!(current_user, 'users.exported', current_user, { count: scope.count })
    send_data content, type: 'text/csv; charset=utf-8', filename: 'nishiohub-users.csv', disposition: 'attachment'
  end

  def import_template
    Administration.authorize!(current_user, 'users.import')
    send_data CSV.generate_line(AdminUserImport::HEADERS), type: 'text/csv', filename: 'nishiohub-user-import-template.csv', disposition: 'attachment'
  end

  def import_preview
    Administration.authorize!(current_user, 'users.import')
    render json: AdminUserImport.new(params[:file]).preview
  end

  def import_users
    users = []
    Administration.transaction do
      current_user.reload
      Administration.authorize!(current_user, 'users.import')
      Administration.authorize!(current_user, 'users.create')
      batch = AdminUserImport.new(params[:file])
      preview = batch.preview
      return render json: preview.merge(detail: 'Correct all CSV errors before importing'), status: :unprocessable_entity unless preview[:valid]
      batch.validated_rows.each do |row|
        # Import never grants administrator roles, even for a Super Admin.
        user = User.new(row.except('password'))
        user.password = row['password']
        user.save!
        Administration.audit!(current_user, 'user.imported', user, { role_id: user.role_id })
        users << user
      end
    end
    render json: { imported: users.size }, status: :created
  end

  private

  def user_data
    source = params.require(:user)
    raise Administration::Rejected.new('User must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source.permit(:full_name, :email, :phone_number, :affiliation, :is_active, :is_verified,
      :primary_role_id, :password, :lock_version, role_ids: []).to_h
  end

  def selected_ids
    raw = params[:user_ids]
    unless raw.is_a?(Array) && raw.size.between?(1, 100) && raw.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      raise Administration::Rejected.new('Select between 1 and 100 users', :unprocessable_entity)
    end
    raw.map(&:to_i).uniq
  end

  def serialize(user)
    AdminUserSerializer.new(user, actor: current_user).as_json
  end
end
