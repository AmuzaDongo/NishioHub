require 'stringio'
module ReportRunner
  def self.authorize!(actor,kind)
    actor.reload
    raise Administration::Rejected,'Account is inactive' unless actor.is_active?
    Administration.authorize!(actor,'dashboard.read')
    Administration.authorize!(actor,'dashboard.manage')
    if kind=='users'
      Administration.authorize!(actor,'users.read')
      Administration.authorize!(actor,'users.export')
    end
  end
  def self.generate!(actor,spec,schedule:nil,scheduled_for:nil)
    authorize!(actor,spec.kind)
    run=actor.report_runs.create!(name:spec.name,kind:spec.kind,filters:spec.filters,columns:spec.columns,report_schedule:schedule,scheduled_for:scheduled_for,status:'running')
    begin
      csv=AnalyticsReport.new(actor,spec.filters).csv(spec.kind,columns:spec.kind=='overview' ? nil : spec.columns)
      authorize!(actor,spec.kind)
      run.file={io:StringIO.new(csv),filename:"report-#{spec.kind}-#{run.id}.csv",content_type:'text/csv',identify:false}
      run.update!(status:'complete',row_count:CSV.parse(csv).length-1,finished_at:Time.current)
      Notification.deliver(user:actor,source_key:"report-ready-#{run.id}",title:'Report Ready',message:"“#{spec.name}” is available in your report history.",category:'system',topic:'platform',icon:'bell',href:"/admin/reports?tab=custom&run=#{run.id}")
    rescue StandardError=>error
      message=error.is_a?(Administration::Rejected) ? error.message : 'Report generation failed. Retry or contact support.'
      Rails.logger.error("Report generation #{run.id}: #{error.class}")
      run.update!(status:'failed',error:message.first(500),finished_at:Time.current)
    end
    run
  end
  def self.run_due!(schedule)
    schedule.with_lock do
      return unless schedule.active&&schedule.next_run_at<=Time.current
      stamp=schedule.next_run_at
      begin
        authorize!(schedule.user,schedule.kind)
        run=ReportRun.find_by(report_schedule:schedule,scheduled_for:stamp)||generate!(schedule.user,schedule,schedule:schedule,scheduled_for:stamp)
        schedule.update!(last_run_at:Time.current,last_status:run.status,last_error:run.error,next_run_at:schedule.next_after(Time.current))
      rescue Administration::Rejected=>error
        schedule.update_columns(active:false,last_status:'failed',last_error:error.message.first(500),last_run_at:Time.current)
      end
    end
  end
end
