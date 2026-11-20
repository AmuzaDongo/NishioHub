class AnalyticsPeriod
  def self.build(filters={})
    source=filters.to_h.symbolize_keys
    if source[:period].blank?||source[:period]=='ytd'
      today=Time.current.in_time_zone(SystemSetting.config['timezone']).to_date
      source.merge!(period:'custom',from:today.beginning_of_year.iso8601,to:today.iso8601)
    end
    AdminReportingPeriod.new(ActionController::Parameters.new(source))
  end
end
