require 'csv'
class Api::V1::AdminResourcesController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user, 'dashboard.read') }
  before_action { response.headers['Cache-Control'] = 'private, no-store' }
  def index
    size = params.fetch(:per_page, 5).to_i
    return render_error('Choose 5, 10, 25 or 50 records per page', :unprocessable_entity) unless [5, 10, 25, 50].include?(size)
    query = AdminResourceQuery.new(params); total = query.filtered.count
    render json: query.report.merge(items: AdminResourceQuery.rows(query.ordered.limit(size).offset((page - 1) * size)), meta: { page: page, per_page: size, total: total, total_pages: (total / size.to_f).ceil }, capabilities: { manage: current_user.management_permission?('dashboard.manage') })
  end
  def show
    resource = PlatformResource.kept.find(params[:id])
    render json: serialize(resource).merge(downloads: resource.platform_resource_accesses.where(kind: 'download').count, link_opens: resource.platform_resource_accesses.where(kind: 'link').count, unique_users: resource.platform_resource_accesses.distinct.count(:user_id))
  end
  def create
    render json: serialize(AdminResourceManagement.save!(current_user, data)), status: :created
  end
  def update
    render json: serialize(AdminResourceManagement.save!(current_user, data, resource: PlatformResource.kept.find(params[:id])))
  end
  def bulk_status
    ids = AdminProgramManagement.ids!(params[:resource_ids]); attrs = AdminResourceManagement.status_attributes(params[:status])
    return render_error('Include displayed resource revisions', :unprocessable_entity) unless params[:versions].is_a?(ActionController::Parameters)
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user)
      resources = PlatformResource.kept.where(id: ids).order(:id).lock.to_a
      raise ActiveRecord::RecordNotFound unless resources.size == ids.size
      resources.each do |r|
        AdminResourceManagement.revision!(r, params[:versions][r.id.to_s]); r.version_actor = current_user; ResourceVersion.capture!(r, current_user); r.update!(attrs)
        Administration.audit!(current_user, 'resource.status_updated', r, { status: params[:status] })
      end
    end
    render json: { updated: ids.size }
  end
  def file
    resource = PlatformResource.kept.find(params[:id]); raise ActiveRecord::RecordNotFound unless resource.file.attached?
    send_data resource.file.download, filename: resource.file.filename.to_s, type: resource.file.content_type, disposition: 'attachment'
  end
  def export
    query = AdminResourceQuery.new(params); scope = query.filtered
    scope = scope.where(id: AdminProgramManagement.ids!(params[:resource_ids])) if params[:resource_ids].present?
    count = scope.count
    return render_error('Filter to at most 10,000 resources before exporting', :unprocessable_entity) if count > 10000
    csv = CSV.generate do |out|
      out << %w[id title description resource_type program uploaded_by size_bytes views status added_on url tags]
      (count / 100.0).ceil.times do |n|
        AdminResourceQuery.rows(query.ordered(scope).limit(100).offset(n * 100)).each do |r|
          out << [r[:id], r[:title], r[:description], r[:resource_type], r.dig(:program, :title), r.dig(:uploaded_by, :name), r.dig(:file, :size), r[:views], r[:status], r[:created_at], r[:url], r[:tags].join('; ')].map { |v| AdminUserQuery.csv_cell(v) }
        end
      end
    end
    Administration.audit!(current_user, 'resources.exported', current_user, { count: count })
    send_data csv, type: 'text/csv; charset=utf-8', filename: 'nishiohub-resources.csv', disposition: 'attachment'
  end
  def import_template
    Administration.authorize!(current_user, 'dashboard.manage')
    send_data CSV.generate_line(AdminResourceImport::HEADERS), type: 'text/csv', filename: 'nishiohub-resource-template.csv'
  end
  def import_preview
    Administration.authorize!(current_user, 'dashboard.manage')
    render json: AdminResourceImport.new(params[:file]).preview
  end
  def import_resources
    count = 0
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user)
      batch = AdminResourceImport.new(params[:file]); result = batch.preview
      return render json: result.merge(detail: 'Correct CSV errors before importing'), status: :unprocessable_entity unless result[:valid]
      batch.validated_rows.each { |row| AdminResourceManagement.save!(current_user, row); count += 1 }
    end
    render json: { imported: count }, status: :created
  end
  private
  def page = [[params.fetch(:page, 1).to_i, 1].max, 100000].min
  def serialize(resource) = AdminResourceQuery.rows(PlatformResource.where(id: resource.id)).first
  def data
    source = params.require(:resource)
    raise Administration::Rejected.new('Resource must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    raise Administration::Rejected.new('Tags must be an array', :unprocessable_entity) if source.key?(:tags) && !source[:tags].is_a?(Array)
    values = source.permit(:title, :description, :resource_type, :status, :url, :platform_program_id, :file, :remove_file, :lock_version, tags: []).to_h
    values['tags'] = [] if source[:clear_tags] == 'true'
    values
  end
end
