require 'csv'
class Api::V1::AdminSessionsController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user, 'dashboard.read') }
  before_action { response.headers['Cache-Control'] = 'private, no-store' }
  def index
    size = params.fetch(:per_page, 5).to_i
    return render_error('Choose 5, 10, 25 or 50 records per page', :unprocessable_entity) unless [5, 10, 25, 50].include?(size)
    query = AdminSessionQuery.new(params); total = query.filtered.count
    render json: query.report.merge(items: AdminSessionQuery.rows(query.ordered.limit(size).offset((page - 1) * size)), meta: meta(total, size),
      capabilities: { manage: current_user.management_permission?('dashboard.manage'), schedule: current_user.management_permission?('dashboard.manage') && SystemSetting.config['matching_enabled'] })
  end
  def show
    booking = Booking.find(params[:id])
    render json: serialize(booking).merge(participants: booking.booking_participants.includes(user: [:profile, :mentor_profile, avatar_attachment: :blob]).order(:id).map { |p| { id: p.user_id, name: p.user.full_name, avatar: p.user.avatar_url } })
  end
  def options
    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
    scope = params[:active_only] == 'true' ? PlatformProgram.active : PlatformProgram.all
    render json: { programs: scope.where('title ILIKE ?', term).order(:title).limit(100).as_json(only: %i[id title]) }
  end
  def create
    render json: serialize(AdminSessionManagement.save!(current_user, data)), status: :created
  end
  def update
    render json: serialize(AdminSessionManagement.save!(current_user, data, booking: Booking.find(params[:id])))
  end
  def change_status
    source = object(:session)
    render json: serialize(AdminSessionManagement.status!(current_user, Booking.find(params[:id]), source[:status], source[:updated_at]))
  end
  def participants
    booking = Booking.find(params[:id]); scope = booking.booking_participants
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
      scope = scope.joins(:user).where('users.full_name ILIKE ?', term)
    end
    total = scope.count
    render json: { items: scope.includes(user: [:profile, :mentor_profile, avatar_attachment: :blob]).order(:id).limit(20).offset((page - 1) * 20).map { |p| { id: p.id, user_id: p.user_id, name: p.user.full_name, avatar: p.user.avatar_url, registered_at: p.created_at.iso8601, attended: p.attended, recorded_at: p.recorded_at&.iso8601 } }, meta: meta(total, 20) }
  end
  def attendance
    source = object(:attendance)
    raise Administration::Rejected.new('Choose attended, absent or unrecorded attendance', :unprocessable_entity) unless source.key?(:attended)
    AdminSessionManagement.attendance!(current_user, Booking.find(params[:id]), params[:participant_id], source[:attended], source[:updated_at])
    head :no_content
  end
  def export
    scope = AdminSessionQuery.new(params).filtered
    scope = scope.where(id: AdminProgramManagement.ids!(params[:session_ids])) if params[:session_ids].present?
    return render_error('Filter to at most 10,000 sessions before exporting', :unprocessable_entity) if scope.count > 10000
    csv = CSV.generate do |out|
      out << %w[id title description program mentor scheduled_at duration format attendees attended status location]
      scope.reorder('bookings.id').find_in_batches(batch_size: 100) do |batch|
        AdminSessionQuery.rows(Booking.where(id: batch.map(&:id)).order(:id)).each { |s| out << [s[:id], s[:title], s[:description], s.dig(:program, :title), s.dig(:mentor, :name), s[:scheduled_at], s[:duration], s[:format], s[:attendees], s[:attended], s[:display_status], s[:location]].map { |v| AdminUserQuery.csv_cell(v) } }
      end
    end
    Administration.audit!(current_user, 'sessions.exported', current_user, { count: scope.count })
    send_data csv, type: 'text/csv; charset=utf-8', filename: 'nishiohub-sessions.csv', disposition: 'attachment'
  end
  def import_template
    Administration.authorize!(current_user, 'dashboard.manage')
    send_data CSV.generate_line(AdminSessionImport::HEADERS), type: 'text/csv', filename: 'nishiohub-session-template.csv'
  end
  def import_preview
    Administration.authorize!(current_user, 'dashboard.manage')
    render json: AdminSessionImport.new(params[:file]).preview
  end
  def import_sessions
    count = 0
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user)
      batch = AdminSessionImport.new(params[:file]); preview = batch.preview
      return render json: preview.merge(detail: 'Correct the CSV errors before importing'), status: :unprocessable_entity unless preview[:valid]
      batch.validated_rows.each { |data| AdminSessionManagement.save!(current_user, data); count += 1 }
    end
    render json: { imported: count }, status: :created
  end
  private
  def serialize(booking) = AdminSessionQuery.rows(Booking.where(id: booking.id)).first
  def page = [[params.fetch(:page, 1).to_i, 1].max, 100000].min
  def meta(total, size) = { page: page, total: total, per_page: size, total_pages: (total / size.to_f).ceil }
  def object(key)
    value = params.require(key)
    raise Administration::Rejected.new("#{key} must be an object", :unprocessable_entity) unless value.is_a?(ActionController::Parameters)
    value
  end
  def data
    source = object(:session)
    source.permit(:title, :description, :mentor_id, :category_id, :program_id, :scheduled_at, :duration, :format, :location, :meeting_url, :updated_at, mentee_ids: []).to_h
  end
end
