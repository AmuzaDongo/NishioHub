require 'csv'
class Api::V1::AdminMenteesController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user, 'users.read') }
  before_action { response.headers['Cache-Control'] = 'no-store' }
  rescue_from ActiveRecord::RecordNotUnique, with: -> { render_error('Email or phone number is already registered', :unprocessable_entity) }
  def index
    size = params.fetch(:per_page, 5).to_i
    return render_error('Page size must be 5, 10, 25 or 50', :unprocessable_entity) unless [5, 10, 25, 50].include?(size)
    page = [[params.fetch(:page, 1).to_i, 1].max, 100000].min
    scope = AdminMenteeQuery.filtered(params)
    count = scope.count
    render json: { mentees: AdminMenteeQuery.rows(AdminMenteeQuery.ordered(scope, params).limit(size).offset((page - 1) * size), current_user),
      meta: { page: page, per_page: size, total: count, total_pages: (count / size.to_f).ceil },
      capabilities: %w[create update status import export].index_with { |key| current_user.management_permission?("users.#{key}") } }.merge(AdminMenteeQuery.report)
  end
  def options
    text = params[:q].to_s.strip.first(100)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(text)}%"
    mentors = User.with_role('mentor')
    mentors = mentors.where(is_active: true) if params[:active_only] == 'true'
    programs = PlatformProgram.all
    programs = programs.active if params[:active_only] == 'true'
    mentors = mentors.where('full_name ILIKE ?', term) if text.present?
    programs = programs.where('title ILIKE ?', term) if text.present?
    render json: { mentors: mentors.order(:full_name).limit(100).map { |u| { id: u.id, name: u.full_name } }, programs: programs.order(:title).limit(100).map { |p| { id: p.id, name: p.title } } }
  end
  def show
    user = AdminMenteeManagement.find!(params[:id])
    render json: { mentee: serialize(user),
      goals: user.mentee_goals.kept.order(created_at: :desc).limit(20).as_json(only: %i[id title progress completed target_date]),
      sessions: user.mentee_bookings.includes(:service, :mentor).order(scheduled_at: :desc).limit(20).map { |b| { id: b.id, title: b.service.title, mentor: b.mentor.full_name, status: b.status, scheduled_at: b.scheduled_at.iso8601 } },
      programs: ProgramMembership.active.where(user_id: user.id).includes(:platform_program).map { |m| { id: m.platform_program_id, title: m.platform_program.title, status: m.platform_program.status } },
      history: AdministrationAudit.where(target_type: 'User', target_id: user.id).order(created_at: :desc).limit(20).as_json(only: %i[id actor_name action created_at]) }
  end
  def create
    render json: serialize(AdminMenteeManagement.save!(current_user, mentee_data)), status: :created
  end
  def update
    render json: serialize(AdminMenteeManagement.save!(current_user, mentee_data, target: AdminMenteeManagement.find!(params[:id])))
  end
  def status
    data = mentee_data.slice('status', 'lock_version', 'profile_version')
    render json: serialize(AdminMenteeManagement.status!(current_user, AdminMenteeManagement.find!(params[:id]), data))
  end
  def bulk_status
    ids = selected_ids
    versions = params[:versions]
    return render_error('Supply account and profile revisions for every selected mentee', :unprocessable_entity) unless versions.is_a?(ActionController::Parameters)
    Administration.transaction do
      current_user.reload
      Administration.authorize!(current_user, 'users.status')
      people = User.with_role('mentee').where(id: ids).order(:id).lock.to_a
      raise ActiveRecord::RecordNotFound unless people.size == ids.size
      people.each do |user|
        revision = versions[user.id.to_s]
        raise Administration::Rejected.new('Missing mentee revisions', :unprocessable_entity) unless revision.is_a?(ActionController::Parameters)
        AdminMenteeManagement.status!(current_user, user, revision.permit(:lock_version, :profile_version).to_h.merge('status' => params[:status]))
      end
    end
    render json: { updated: ids.size }
  end
  def export
    Administration.authorize!(current_user, 'users.export')
    scope = AdminMenteeQuery.filtered(params)
    scope = scope.where(id: selected_ids) if params[:user_ids].present?
    return render_error('Filter to at most 10,000 mentees before exporting', :unprocessable_entity) if scope.count > 10000
    content = CSV.generate do |csv|
      csv << %w[id full_name email phone_number school grade program mentor progress completed_sessions status joined_at]
      # Keep export memory bounded and preserve the chosen sort order.
      ordered = AdminMenteeQuery.ordered(scope, params)
      (scope.count / 100.0).ceil.times do |index|
        AdminMenteeQuery.rows(ordered.limit(100).offset(index * 100), current_user).each do |u|
          csv << [u[:id], u[:full_name], u[:email], u[:phone_number], u[:school], u[:grade], u.dig(:program, :title), u.dig(:mentor, :name), u[:progress], u[:completed_sessions], u[:status], u[:created_at]].map { |cell| AdminUserQuery.csv_cell(cell) }
        end
      end
    end
    Administration.audit!(current_user, 'mentees.exported', current_user, { count: scope.count })
    send_data content, type: 'text/csv; charset=utf-8', filename: 'nishiohub-mentees.csv', disposition: 'attachment'
  end
  def import_template
    Administration.authorize!(current_user, 'users.import')
    role = Role.all.find { |r| r.canonical_name == 'mentee' }
    content = CSV.generate { |csv| csv << AdminUserImport::HEADERS; csv << ['Example Learner', 'learner@example.test', '+256700000001', role&.name || 'mentee', 'Example School', 'ReplaceWithPrivatePassword'] }
    send_data content, type: 'text/csv', filename: 'nishiohub-mentee-template.csv'
  end
  def import_preview
    Administration.authorize!(current_user, 'users.import')
    render json: AdminUserImport.new(params[:file], required_role: 'mentee').preview
  end
  def import_mentees
    count = 0
    Administration.transaction do
      current_user.reload
      Administration.authorize!(current_user, 'users.import')
      Administration.authorize!(current_user, 'users.create')
      batch = AdminUserImport.new(params[:file], required_role: 'mentee')
      preview = batch.preview
      return render json: preview.merge(detail: 'Correct all CSV errors before importing'), status: :unprocessable_entity unless preview[:valid]
      batch.validated_rows.each do |row|
        user = User.new(row.except('password'))
        user.password = row['password']
        user.save!
        Administration.audit!(current_user, 'mentee.imported', user, { role_id: user.role_id })
        count += 1
      end
    end
    render json: { imported: count }, status: :created
  end
  private
  def serialize(user) = AdminMenteeQuery.rows(AdminMenteeQuery.base.where(users: { id: user.id }), current_user).first
  def mentee_data
    source = params.require(:mentee)
    raise Administration::Rejected.new('Mentee must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    if source.key?(:interests) && !source[:interests].is_a?(Array)
      raise Administration::Rejected.new('Interests must be an array', :unprocessable_entity)
    end
    source.permit(:full_name, :email, :phone_number, :password, :school, :grade, :location, :status, :mentor_id, :program_id, :lock_version, :profile_version, :education, :bio, interests: []).to_h
  end
  def selected_ids
    raw = params[:user_ids]
    unless raw.is_a?(Array) && raw.size.between?(1, 100) && raw.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      raise Administration::Rejected.new('Select 1–100 valid mentees', :unprocessable_entity)
    end
    raw.map(&:to_i).uniq
  end
end
