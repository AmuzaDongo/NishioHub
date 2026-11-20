namespace :reports do
  desc 'Recover and run due persisted report schedules; safe alongside delayed jobs'
  task run_due: :environment do
    ReportSchedule.where(active:true).where('next_run_at <= ?',Time.current).order(:next_run_at).limit(100).each{|schedule|ReportRunner.run_due!(schedule)}
  end
end
