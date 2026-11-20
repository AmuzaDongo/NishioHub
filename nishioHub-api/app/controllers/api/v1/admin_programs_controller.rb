require 'csv'
class Api::V1::AdminProgramsController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user, 'dashboard.read') }
  before_action { response.headers['Cache-Control'] = 'private, no-store' }
  def index
    per_page = params.fetch(:per_page, 5).to_i
    return render_error('Choose 5, 10, 25 or 50 records per page', :unprocessable_entity) unless [5, 10, 25, 50].include?(per_page)
    query = AdminProgramQuery.new(params)
    count = query.filtered.count
    render json: { programs: query.rows(query.ordered.limit(per_page).offset((page - 1) * per_page)),
      meta: { page: page, per_page: per_page, total: count, total_pages: (count / per_page.to_f).ceil },
      capabilities: { manage: current_user.management_permission?('dashboard.manage'), view_users: current_user.management_permission?('users.read') } }.merge(query.report)
  end
  def show
    program = PlatformProgram.find(params[:id])
    members = program.program_memberships.where(is_active: true, user_id: User.with_role('mentee').select(:id))
    groups = { completed: members.where(progress: 100).count, in_progress: members.where(progress: 1..99).count, not_started: members.where(progress: 0).count }
    render json: serialize(program).merge(
      sessions: program.bookings.count, resources: program.platform_resources.kept.count,
      public_details: ProgramPublicDetails::DEFAULTS.merge(program.public_details), capacity: program.capacity, objectives: program.objectives, target_audience: program.target_audience,
      delivery_mode: program.delivery_mode, registration_starts_on: program.registration_starts_on,
      registration_ends_on: program.registration_ends_on, evaluation_starts_on: program.evaluation_starts_on,
      evaluation_ends_on: program.evaluation_ends_on, progress_counts: groups,
      capabilities: { manage: current_user.management_permission?('dashboard.manage'), view_users: current_user.management_permission?('users.read'), schedule: current_user.management_permission?('dashboard.manage') && SystemSetting.config['matching_enabled'] })
  end
  def options
    q = params[:q].to_s.strip.first(100)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
    scope = User.with_role(params[:kind] == 'mentees' ? 'mentee' : 'mentor')
    scope = scope.where(is_active: true) if params[:active_only] == 'true'
    scope = scope.where('full_name ILIKE ?', term) if q.present?
    categories = params[:active_only] == 'true' ? Category.active : Category.all
    categories = categories.where('name ILIKE ?', term) if q.present?
    render json: { people: scope.includes(:profile, :mentor_profile, avatar_attachment: :blob).order(:full_name).limit(100).map { |u| { id: u.id, name: u.full_name, avatar: u.avatar_url } },
      categories: categories.order(:name).limit(100).map { |c| { id: c.id, name: c.name } } }
  end
  def create
    render json: serialize(AdminProgramManagement.save!(current_user, data)), status: :created
  end
  def update
    render json: serialize(AdminProgramManagement.save!(current_user, data, program: PlatformProgram.find(params[:id])))
  end
  def bulk_status
    ids = AdminProgramManagement.ids!(params[:program_ids])
    return render_error('Choose active, draft or archived status and displayed revisions', :unprocessable_entity) unless %w[active draft archived].include?(params[:status]) && params[:versions].is_a?(ActionController::Parameters)
    Administration.transaction do
      authorize_write!
      programs = PlatformProgram.where(id: ids).order(:id).lock.to_a
      raise ActiveRecord::RecordNotFound unless programs.size == ids.size
      programs.each { |program| AdminProgramManagement.save!(current_user, { 'status' => params[:status], 'lock_version' => params[:versions][program.id.to_s] }, program: program) }
    end
    render json: { updated: ids.size }
  end
  def members
    program = PlatformProgram.find(params[:id])
    status = params[:status].presence || 'active'
    return render_error('Choose active, withdrawn or all enrollments', :unprocessable_entity) unless %w[active withdrawn all].include?(status)
    scope = program.program_memberships.where(user_id: User.with_role('mentee').select(:id))
    scope = scope.where(is_active: status == 'active') unless status == 'all'
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
      scope = scope.joins(:user).where('users.full_name ILIKE ?', term)
    end
    count = scope.count
    rows = scope.includes(user: [:profile, :mentor_profile, avatar_attachment: :blob]).order(:id).limit(20).offset((page - 1) * 20)
    render json: { items: rows.map { |m| { id: m.id, user_id: m.user_id, name: m.user.full_name, email: current_user.management_permission?('users.read') ? m.user.email : nil, avatar: m.user.avatar_url, account_active: m.user.is_active?, active: m.is_active?, progress: m.progress, completed_at: m.completed_at&.iso8601, joined_at: m.created_at.iso8601, lock_version: m.lock_version } }, meta: meta(count) }
  end
  def add_members
    AdminProgramManagement.members!(current_user, params[:id], params[:user_ids])
    head :no_content
  end
  def update_member
    source = params.require(:enrollment)
    return render_error('Enrollment must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    AdminProgramManagement.change_member!(current_user, params[:id], params[:membership_id], source[:lock_version], source.permit(:progress).to_h.symbolize_keys)
    head :no_content
  end
  def remove_member
    AdminProgramManagement.change_member!(current_user, params[:id], params[:membership_id], params[:lock_version], { is_active: false })
    head :no_content
  end
  def records
    program = PlatformProgram.find(params[:id])
    scope = case params[:type]
    when 'sessions' then program.bookings.includes(:service, :mentor, :mentee, :platform_program).order(scheduled_at: :desc)
    when 'resources' then program.platform_resources.kept.includes(:platform_program, file_attachment: :blob).order(created_at: :desc)
    else return render_error('Choose sessions or resources', :unprocessable_entity)
    end
    count = scope.count
    render json: { items: scope.limit(20).offset((page - 1) * 20).map { |r| AdminOperationSerializer.new(r, actor: current_user).as_json }, meta: meta(count) }
  end
  def export
    query = AdminProgramQuery.new(params)
    scope = query.filtered
    scope = scope.where(id: AdminProgramManagement.ids!(params[:program_ids])) if params[:program_ids].present?
    count = scope.count
    return render_error('Filter to at most 10,000 programs before exporting', :unprocessable_entity) if count > 10000
    csv = CSV.generate do |out|
      out << %w[id title description category mentors enrolled progress rating status starts_on ends_on]
      (count / 100.0).ceil.times do |offset|
        query.rows(query.ordered(scope).limit(100).offset(offset * 100)).each { |p| out << [p[:id], p[:title], p[:description], p.dig(:category, :name), p[:mentors].map { |m| m[:name] }.join('; '), p[:enrolled], p[:progress], p[:rating], p[:display_status], p[:starts_on], p[:ends_on]].map { |c| AdminUserQuery.csv_cell(c) } }
      end
    end
    Administration.audit!(current_user, 'programs.exported', current_user, { count: count })
    send_data csv, type: 'text/csv; charset=utf-8', filename: 'nishiohub-programs.csv', disposition: 'attachment'
  end
  def import_template
    Administration.authorize!(current_user, 'dashboard.manage')
    send_data CSV.generate_line(AdminProgramImport::HEADERS), type: 'text/csv', filename: 'nishiohub-program-template.csv', disposition: 'attachment'
  end
  def import_preview
    Administration.authorize!(current_user, 'dashboard.manage')
    render json: AdminProgramImport.new(params[:file]).preview
  end
  def import_programs
    count = 0
    Administration.transaction do
      authorize_write!
      batch = AdminProgramImport.new(params[:file])
      preview = batch.preview
      return render json: preview.merge(detail: 'Correct the CSV errors before importing'), status: :unprocessable_entity unless preview[:valid]
      batch.validated_rows.each { |row| AdminProgramManagement.save!(current_user, row); count += 1 }
    end
    render json: { imported: count }, status: :created
  end
  private
  def page = [[params.fetch(:page, 1).to_i, 1].max, 100000].min
  def meta(count) = { page: page, per_page: 20, total: count, total_pages: (count / 20.0).ceil }
  def serialize(program) = AdminProgramQuery.new.rows(PlatformProgram.where(id: program.id)).first
  def authorize_write!
    current_user.reload
    Administration.authorize!(current_user, 'dashboard.read')
    Administration.authorize!(current_user, 'dashboard.manage')
  end
  def data
    source = params.require(:program)
    raise Administration::Rejected.new('Program must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    if source.key?(:public_details_json)
      raise Administration::Rejected.new('Send only one public details object',:unprocessable_entity) if source.key?(:public_details)
      begin
        parsed=JSON.parse(source[:public_details_json].to_s)
        raise JSON::ParserError unless parsed.is_a?(Hash)
        source[:public_details]=parsed
      rescue JSON::ParserError
        raise Administration::Rejected.new('Public details must be a valid JSON object',:unprocessable_entity)
      end
    end
    if source.key?(:objectives) && !source[:objectives].is_a?(Array)
      raise Administration::Rejected.new('Objectives must be an array', :unprocessable_entity)
    end
    if source.key?(:mentor_ids) && !source[:mentor_ids].is_a?(Array)
      raise Administration::Rejected.new('Mentors must be an array', :unprocessable_entity)
    end
    %w[audience_stages themes].each do |field|
      raise Administration::Rejected.new("#{field.humanize} must be an array",:unprocessable_entity) if source.key?(field)&&!source[field].is_a?(Array)
    end
    source.permit(:featured, :title, :description, :category_id, :icon, :status, :starts_on, :ends_on, :lock_version, :capacity, :target_audience, :delivery_mode, :registration_starts_on, :registration_ends_on, :evaluation_starts_on, :evaluation_ends_on, :banner, :remove_banner, objectives: [], mentor_ids: [], audience_stages: [], themes: []).to_h.tap{|data|data['public_details']=source[:public_details].is_a?(ActionController::Parameters) ? source[:public_details].to_unsafe_h : source[:public_details] if source.key?(:public_details);%w[mentor_ids objectives audience_stages themes].each{|field|data[field]=data[field].reject{|value|value==''} if data[field].is_a?(Array)}}
  end
end
