require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module NishiohubApi
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
    config.active_record.schema_format = :ruby
    config.generators.system_tests = nil
  end
end
