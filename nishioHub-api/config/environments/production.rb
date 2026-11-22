Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.log_level = :info
  config.log_tags = [:request_id]
  config.active_storage.service = :local
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
  config.force_ssl = ENV["FORCE_SSL"] == "true"
  config.hosts.clear if ENV["DISABLE_HOST_CHECK"] == "true"
end
