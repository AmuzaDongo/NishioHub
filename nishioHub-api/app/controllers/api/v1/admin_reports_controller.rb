class Api::V1::AdminReportsController < ApplicationController
  before_action :require_admin!
  before_action ->{Administration.authorize!(current_user,'dashboard.read')}
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    page;size
    report=AnalyticsReport.new(current_user,filters)
    tab=params[:tab].presence||'overview'
    raise Administration::Rejected.new('Choose a valid report section',:unprocessable_entity) unless (['overview','custom']+AnalyticsReport::DATASETS.keys).include?(tab)
    payload=report.overview.merge(catalog:AnalyticsReport::DATASETS)
    if AnalyticsReport::DATASETS.key?(tab)
      payload[:table]=report.table(tab,page:page,size:size)
    elsif tab=='custom'
      payload[:saved]=current_user.saved_reports.order(updated_at: :desc).limit(50).map{|r|serialize_spec(r)}
      payload[:schedules]=current_user.report_schedules.order(created_at: :desc).limit(50).map{|r|serialize_schedule(r)}
      runs=current_user.report_runs.order(created_at: :desc)
      payload[:runs]=runs.limit(10).offset((page-1)*10).map{|r|serialize_run(r)}
      payload[:runs_meta]={page:page,per_page:10,total:runs.count,total_pages:(runs.count/10.0).ceil}
    end
    render json:payload
  end
  def export
    kind=params[:kind].presence||'overview';report=AnalyticsReport.new(current_user,filters)
    content=report.csv(kind)
    Administration.audit!(current_user,'reports.exported',current_user,{kind:kind,filters:filters.to_h})
    send_data content,type:'text/csv; charset=utf-8',filename:"nishiohub-#{kind}-report.csv"
  end
  def save_custom
    source=object(:report);record=nil
    write do
      record=params[:report_id] ? current_user.saved_reports.lock.find(params[:report_id]) : current_user.saved_reports.new
      AdminGoalManagement.revision!(record,source[:lock_version]) if record.persisted?
      raise Administration::Rejected.new('Keep at most 50 saved reports',:unprocessable_entity) if record.new_record?&&current_user.saved_reports.count>=50
      record.assign_attributes(source.permit(:name,:kind,columns:[],filters:AnalyticsReport::FILTER_KEYS));authorize_kind!(record.kind);record.save!
      Administration.audit!(current_user,'reports.custom_saved',record,{kind:record.kind,name:record.name})
    end
    render json:serialize_spec(record)
  end
  def custom
    record=current_user.saved_reports.find(params[:report_id]);report=AnalyticsReport.new(current_user,record.filters)
    render json:report.table(record.kind,page:page,size:size,columns:record.columns)
  end
  def custom_export
    record=current_user.saved_reports.find(params[:report_id]);content=AnalyticsReport.new(current_user,record.filters).csv(record.kind,columns:record.columns)
    Administration.audit!(current_user,'reports.custom_exported',record,{})
    send_data content,type:'text/csv; charset=utf-8',filename:"nishiohub-custom-#{record.id}.csv"
  end
  def remove_custom
    write do
      record=current_user.saved_reports.lock.find(params[:report_id]);AdminGoalManagement.revision!(record,params[:lock_version]);Administration.audit!(current_user,'reports.custom_removed',record,{name:record.name});record.destroy!
    end
    head :no_content
  end
  def save_schedule
    source=object(:schedule);schedule=nil
    write do
      schedule=params[:schedule_id] ? current_user.report_schedules.lock.find(params[:schedule_id]) : current_user.report_schedules.new
      AdminGoalManagement.revision!(schedule,source[:lock_version]) if schedule.persisted?
      raise Administration::Rejected.new('Keep at most 50 schedules',:unprocessable_entity) if schedule.new_record?&&current_user.report_schedules.count>=50
      attrs=source.permit(:name,:kind,:frequency,:hour,:minute,:weekday,:month_day,:active,columns:[],filters:AnalyticsReport::FILTER_KEYS).to_h
      schedule.assign_attributes(attrs);schedule.timezone||=SystemSetting.config['timezone'];authorize_kind!(schedule.kind)
      Administration.authorize!(current_user,'users.export') if schedule.kind=='users'
      schedule.next_run_at=schedule.next_after(Time.current)
      schedule.save!;Administration.audit!(current_user,'reports.schedule_saved',schedule,{frequency:schedule.frequency,active:schedule.active})
    end
    render json:serialize_schedule(schedule)
  end
  def remove_schedule
    write do
      schedule=current_user.report_schedules.lock.find(params[:schedule_id]);AdminGoalManagement.revision!(schedule,params[:lock_version]);Administration.audit!(current_user,'reports.schedule_removed',schedule,{});schedule.destroy!
    end
    head :no_content
  end
  def run_schedule
    run=nil
    write do
      schedule=current_user.report_schedules.find(params[:schedule_id]);run=ReportRunner.generate!(current_user,schedule,schedule:schedule)
      Administration.audit!(current_user,'reports.manual_run',schedule,{run_id:run.id})
    end
    render json:serialize_run(run)
  end
  def download_run
    run=current_user.report_runs.find(params[:run_id]);authorize_kind!(run.kind)
    Administration.authorize!(current_user,'users.export') if run.kind=='users'
    raise ActiveRecord::RecordNotFound unless run.status=='complete'&&run.file.attached?
    Administration.audit!(current_user,'reports.run_downloaded',run,{})
    send_data run.file.download,type:'text/csv; charset=utf-8',filename:run.file.filename.to_s
  end
  private
  def filters = params.permit(:period,:from,:to,:q,:program_id).to_h
  def object(key)
    source=params.require(key);raise Administration::Rejected.new("#{key} must be an object",:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source
  end
  def page = integer(:page,1,1..10000)
  def size = integer(:per_page,10,[10,25,50])
  def integer(key,default,allowed)
    raw=params.fetch(key,default).to_s
    raise Administration::Rejected.new("Invalid #{key}",:unprocessable_entity) unless raw.match?(/\A\d+\z/)&&allowed.include?(raw.to_i)
    raw.to_i
  end
  def authorize_kind!(kind)
    raise Administration::Rejected.new('Choose a valid report dataset',:unprocessable_entity) unless (['overview']+AnalyticsReport::DATASETS.keys).include?(kind)
    Administration.authorize!(current_user,'users.read') if kind=='users'
  end
  def write
    Administration.transaction do
      current_user.reload;Administration.authorize!(current_user,'dashboard.read');Administration.authorize!(current_user,'dashboard.manage');yield
    end
  end
  def serialize_spec(r) = {id:r.id,name:r.name,kind:r.kind,columns:r.columns,filters:r.filters,lock_version:r.lock_version}
  def serialize_schedule(r) = serialize_spec(r).merge(frequency:r.frequency,hour:r.hour,minute:r.minute,weekday:r.weekday,month_day:r.month_day,timezone:r.timezone,active:r.active,next_run_at:r.next_run_at.iso8601,last_run_at:r.last_run_at&.iso8601,last_status:r.last_status,last_error:r.last_error)
  def serialize_run(r) = {id:r.id,name:r.name,kind:r.kind,status:r.status,row_count:r.row_count,error:r.error,created_at:r.created_at.iso8601,finished_at:r.finished_at&.iso8601}
end
