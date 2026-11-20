class AdminPlatformHealth
  def self.call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ApplicationRecord.connection.select_value('SELECT 1')
    db_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
    service = ActiveStorage::Blob.service
    storage = { key: 'storage', label: 'Storage', status: 'unknown', value: "Configured (#{Rails.application.config.active_storage.service})", detail: 'Remote storage is not probed by this dashboard.' }
    if service.is_a?(ActiveStorage::Service::DiskService)
      path = Pathname.new(service.root)
      path = path.parent until path.exist? || path == path.parent
      accessible = path.directory? && path.readable? && path.writable?
      storage = { key: 'storage', label: 'Storage', status: accessible ? 'ok' : 'attention', value: accessible ? 'Accessible' : 'Not writable', detail: 'Checks local storage directory access; disk usage is not monitored.' }
    end
    config = SystemSetting.config
    adapter = ActiveJob::Base.queue_adapter.class.name.demodulize.sub('Adapter', '')
    { checked_at: Time.current.iso8601, uptime_seconds: Rails.application.config.x.platform_process_started ? (Process.clock_gettime(Process::CLOCK_MONOTONIC) - Rails.application.config.x.platform_process_started).to_i : nil,
      uptime_scope: 'Current API process; historical availability is not monitored.',
      checks: [
        { key: 'application', label: 'Application', status: config['platform_mode'] == 'maintenance' ? 'attention' : 'ok', value: config['platform_mode'] == 'maintenance' ? 'Maintenance' : 'Responding', detail: 'The authenticated API request completed.' },
        { key: 'database', label: 'Database', status: 'ok', value: 'Connected', detail: "SELECT 1 completed in #{db_ms} ms." },
        storage,
        { key: 'jobs', label: 'Queue/Jobs', status: 'unknown', value: "#{adapter} adapter", detail: 'Worker execution and backlog are not monitored.' },
        { key: 'email', label: 'Email Service', status: 'unknown', value: Rails.env.test? ? 'Test transport' : SystemSetting.mail_configured? ? 'Configured' : 'Not configured', detail: 'Configuration status only. Use Send Test Email in System Settings to test delivery.' }
      ] }
  rescue ActiveStorage::Error, IOError, SystemCallError
    { checked_at: Time.current.iso8601, uptime_seconds: nil, uptime_scope: 'Health probe could not complete.', checks: [{ key: 'storage', label: 'Storage', status: 'attention', value: 'Probe unavailable', detail: 'Check the configured storage provider.' }] }
  end
end
