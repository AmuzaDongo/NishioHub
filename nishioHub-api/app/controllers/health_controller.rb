class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.select_value('SELECT 1')
    response.headers['Cache-Control'] = 'no-store'
    head :ok
  rescue StandardError => error
    Rails.logger.error("Readiness check failed: #{error.class}")
    head :service_unavailable
  end
end
