if ENV['SMTP_ADDRESS'].present? && !Rails.env.test?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV['SMTP_ADDRESS'], port: ENV.fetch('SMTP_PORT', 587).to_i,
      user_name: ENV['SMTP_USERNAME'], password: ENV['SMTP_PASSWORD'],
      domain: ENV['SMTP_DOMAIN'], authentication: ENV.fetch('SMTP_AUTHENTICATION', 'plain'),
      enable_starttls_auto: true, open_timeout: 5, read_timeout: 10
    }.compact
  end
end
