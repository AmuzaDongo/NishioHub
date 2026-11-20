class ReportSchedule < ApplicationRecord
  include ReportSpecification
  has_many :report_runs,dependent: :nullify
  validates :frequency,inclusion:{in:%w[daily weekly monthly]}
  validates :hour,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than:24}
  validates :minute,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than:60}
  validates :weekday,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than:7}
  validates :month_day,numericality:{only_integer:true,greater_than:0,less_than_or_equal_to:28}
  validates :next_run_at,presence:true
  validates :active,inclusion:{in:[true,false]}
  validate {errors.add(:timezone,'is invalid') unless ActiveSupport::TimeZone[timezone.to_s]}
  after_commit :enqueue_next,if: ->{active&&(previously_new_record?||saved_change_to_next_run_at?||saved_change_to_active?)}
  def next_after(at)
    zone=ActiveSupport::TimeZone[timezone.to_s]
    return nil unless zone&&%w[daily weekly monthly].include?(frequency)&&hour&.between?(0,23)&&minute&.between?(0,59)&&weekday&.between?(0,6)&&month_day&.between?(1,28)
    local=at.in_time_zone(zone);date=local.to_date
    date+=((weekday-date.wday)%7) if frequency=='weekly'
    date=Date.new(date.year,date.month,month_day) if frequency=='monthly'
    candidate=zone.local(date.year,date.month,date.day,hour,minute)
    if candidate<=at
      date=frequency=='monthly' ? date.next_month : date+(frequency=='weekly' ? 7 : 1)
      candidate=zone.local(date.year,date.month,date.day,hour,minute)
    end
    candidate
  end
  def enqueue_next
    ReportScheduleJob.set(wait_until:next_run_at).perform_later(id,next_run_at.iso8601(6))
  end
end
