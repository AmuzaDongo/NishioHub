require 'csv'
class Api::V1::AdminEventsController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user,'dashboard.read') }
  before_action { response.headers['Cache-Control']='private, no-store' }
  def index
    query=AdminEventQuery.new(params);size=per_page;total=query.filtered.count
    render json:query.report.merge(items:AdminEventQuery.rows(query.ordered.limit(size).offset((page-1)*size)),meta:{page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil},capabilities:{manage:current_user.management_permission?('dashboard.manage')})
  end
  def show
    render json:serialize(event)
  end
  def create
    render json:serialize(AdminEventManagement.save!(current_user,data)),status: :created
  end
  def update
    render json:serialize(AdminEventManagement.save!(current_user,data,event:event))
  end
  def status
    render json:serialize(AdminEventManagement.change_status!(current_user,event,params[:status],params[:lock_version]))
  end
  def attendees
    scope=event.event_registrations.includes(user:[:profile,avatar_attachment: :blob])
    scope=scope.joins(:user).where('users.full_name ILIKE :q OR users.email ILIKE :q',q:"%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(150))}%") if params[:q].present?
    if params[:status].present? && params[:status]!='all'
      raise Administration::Rejected.new('Invalid registration filter',:unprocessable_entity) unless %w[registered cancelled].include?(params[:status])
      scope=scope.where(status:params[:status])
    end
    if params[:attendance].present? && params[:attendance]!='all'
      raise Administration::Rejected.new('Invalid attendance filter',:unprocessable_entity) unless %w[present absent unrecorded].include?(params[:attendance])
      scope=scope.where(attendance_status:params[:attendance])
    end
    total=scope.count;size=per_page
    render json:{items:scope.order(:created_at,:id).limit(size).offset((page-1)*size).map{|r|{id:r.id,user_id:r.user_id,name:r.user.full_name,email:r.user.email,status:r.status,attendance_status:r.attendance_status,lock_version:r.lock_version}},meta:{page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil}}
  end
  def people
    Administration.authorize!(current_user,'dashboard.manage')
    term="%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
    render json:User.where(is_active:true).where('full_name ILIKE ? OR email ILIKE ?',term,term).order(:full_name,:id).limit(50).map{|u|{id:u.id,name:u.full_name}}
  end
  def add_attendees
    AdminEventManagement.add_attendees!(current_user,event,params[:user_ids]);render json:serialize(event.reload)
  end
  def update_attendee
    source=params.require(:registration).permit(:lock_version,:attendance_status,:cancel).to_h
    AdminEventManagement.registration!(current_user,event,params[:registration_id],source);head :no_content
  end
  def calendar
    r=EventRegistration.new(event:event,user:current_user,reminder_minutes:0)
    send_data EventCalendarDocument.new(r).render,type:'text/calendar; charset=utf-8',filename:"nishiohub-event-#{event.id}.ics"
  end
  def export_attendees
    rows=event.event_registrations.includes(:user).order(:id)
    csv=CSV.generate do |out|
      out<<%w[name email registration_status attendance_status registered_on]
      rows.each{|r|out<<[r.user.full_name,r.user.email,r.status,r.attendance_status,r.created_at.iso8601].map{|v|AdminUserQuery.csv_cell(v)}}
    end
    Administration.audit!(current_user,'event.attendees_exported',event,{count:rows.count})
    send_data csv,type:'text/csv; charset=utf-8',filename:"event-#{event.id}-attendees.csv"
  end
  def export
    query=AdminEventQuery.new(params);scope=query.filtered
    scope=scope.where(id:AdminProgramManagement.ids!(params[:event_ids])) if params[:event_ids].present?
    count=scope.count
    return render_error('Filter to at most 10,000 events before exporting',:unprocessable_entity) if count>10000
    csv=CSV.generate do |out|
      out<<%w[id title description event_type program_id program starts_at ends_at format location capacity status attendees]
      (count/100.0).ceil.times do |n|
        AdminEventQuery.rows(query.ordered(scope).limit(100).offset(n*100)).each{|r|out<<[r[:id],r[:title],r[:description],r[:event_type],r.dig(:program,:id),r.dig(:program,:title),r[:starts_at],r[:ends_at],r[:format],r[:location],r[:capacity],r[:status],r[:attendees]].map{|v|AdminUserQuery.csv_cell(v)}}
      end
    end
    Administration.audit!(current_user,'events.exported',current_user,{count:count});send_data csv,type:'text/csv; charset=utf-8',filename:'nishiohub-events.csv'
  end
  def import_template
    Administration.authorize!(current_user,'dashboard.manage')
    send_data CSV.generate_line(AdminEventImport::HEADERS),type:'text/csv',filename:'nishiohub-events-template.csv'
  end
  def import_preview
    Administration.authorize!(current_user,'dashboard.manage');render json:AdminEventImport.new(params[:file],current_user).preview
  end
  def import_events
    count=0
    Administration.transaction do
      AdminEventManagement.authorize!(current_user);batch=AdminEventImport.new(params[:file],current_user);result=batch.preview
      return render json:result.merge(detail:'Correct all CSV errors before importing'),status: :unprocessable_entity unless result[:valid]
      batch.validated_rows.each{|row|AdminEventManagement.save!(current_user,row);count+=1}
    end
    render json:{imported:count},status: :created
  end
  private
  def event = @event ||= Event.kept.find(params[:id])
  def serialize(record) = AdminEventQuery.rows(Event.where(id:record.id)).first
  def page = [[params.fetch(:page,1).to_i,1].max,100000].min
  def per_page
    size=params.fetch(:per_page,5).to_i
    raise Administration::Rejected.new('Choose 5, 10, 25 or 50 records per page',:unprocessable_entity) unless [5,10,25,50].include?(size)
    size
  end
  def data
    source=params.require(:event)
    raise Administration::Rejected.new('Event must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source.permit(:title,:description,:event_type,:status,:format,:location,:meeting_url,:capacity,:platform_program_id,:starts_at,:ends_at,:lock_version,:banner,:remove_banner,:public_featured,:public_recording_url,target_audiences:[],public_details:{objectives:[],faqs:[:question,:answer]}).to_h.tap{|data|data['public_details']=source[:public_details] if source[:public_details].is_a?(String)}
  end
end
