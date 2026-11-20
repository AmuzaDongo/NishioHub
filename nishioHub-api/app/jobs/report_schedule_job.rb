class ReportScheduleJob < ActiveJob::Base
  queue_as :default
  def perform(id,expected_at)
    schedule=ReportSchedule.find_by(id:id)
    return unless schedule&&schedule.active&&schedule.next_run_at.iso8601(6)==expected_at
    ReportRunner.run_due!(schedule)
  end
end
