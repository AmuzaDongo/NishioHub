class AdminReportingPeriod
  attr_reader :starts_on, :ends_on, :zone, :days
  def initialize(params)
    @zone = ActiveSupport::TimeZone[SystemSetting.config['timezone']]
    today = Time.current.in_time_zone(@zone).to_date
    if params[:period] == 'custom'
      @starts_on = Date.iso8601(params.require(:from).to_s)
      @ends_on = Date.iso8601(params.require(:to).to_s)
    else
      selected = (params[:period].presence || '30').to_s
      raise ArgumentError unless selected.in?(%w[7 30 90])
      @days = selected.to_i
      @ends_on = today
      @starts_on = today - (@days - 1)
    end
    @days = (@ends_on - @starts_on).to_i + 1
    raise ArgumentError unless @days.between?(1, 366) && @ends_on <= today
  rescue ArgumentError, Date::Error
    raise Administration::Rejected.new('Choose a valid reporting range of 1–366 days ending no later than today', :unprocessable_entity)
  end

  def begins_at = zone.local(starts_on.year, starts_on.month, starts_on.day)
  def finishes_at
    date = ends_on + 1
    zone.local(date.year, date.month, date.day)
  end
  def range = begins_at...finishes_at
  def previous_range = (begins_at - days.days)...begins_at
  def json = { from: starts_on.iso8601, to: ends_on.iso8601, days: days, timezone: zone.tzinfo.name }
  def self.change(current, previous)
    previous.zero? ? nil : ((current - previous) * 100.0 / previous).round(1)
  end
end
