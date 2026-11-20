class Api::V1::SystemSettingsController < ApplicationController
  before_action :require_admin!, except: %i[public_config public_events]
  before_action -> { Administration.authorize!(current_user, 'system.manage') }, except: %i[public_config public_events]
  before_action { response.headers['Cache-Control'] = 'no-store' }

  def show
    render json: workspace
  end

  def public_config
    render json: setting.config.slice(*%w[platform_name tagline organization_name support_email support_phone timezone language date_format currency platform_mode registration_enabled require_email_verification default_registration_role matching_enabled public_events_enabled support_url maintenance_message password_min_length]).merge(assets)
  end

  def public_events
    return render json: [] unless setting.config['public_events_enabled']

    render json: Event.kept.where(status: 'published').where('starts_at > ?', Time.current).order(:starts_at).limit(3).map { |event| event.as_json(only: %i[id title description category starts_at location]).merge(image: event.image_path) }
  end

  def update
    source = params.require(:settings)
    return render_error('Settings must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)

    apply_values(source.to_unsafe_h, 'settings.updated')
  end

  def upload_asset
    kind = params[:kind].to_s
    return render_error('Choose logo or favicon', :unprocessable_entity) unless kind.in?(%w[logo favicon])
    file = params[:file]
    allowed = kind == 'logo' ? %w[image/png image/jpeg image/webp] : %w[image/png image/vnd.microsoft.icon image/x-icon]
    unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 2.megabytes && file.content_type.in?(allowed) && Marcel::MimeType.for(file.tempfile).in?(allowed)
      return render_error('Choose a supported image up to 2 MB', :unprocessable_entity)
    end
    setting.with_lock do
      return conflict unless current_revision?
      # Keep attachment_changes until after_commit has uploaded the file.
      # Reloading here clears that pending upload while leaving a blob record behind.
      setting.public_send("#{kind}=", file)
      setting.updated_by = current_user
      setting.updated_at = Time.current
      setting.save!
      record_audit('branding.uploaded', { kind => { filename: file.original_filename.to_s.first(200) } })
    end
    render json: workspace
  end

  def remove_asset
    kind = params[:kind].to_s
    return render_error('Choose logo or favicon', :unprocessable_entity) unless kind.in?(%w[logo favicon])
    old = nil
    setting.with_lock do
      return conflict unless current_revision?
      attachment = setting.public_send(kind)
      old = attachment.blob if attachment.attached?
      attachment.detach
      setting.update!(updated_by: current_user, updated_at: Time.current)
      record_audit('branding.removed', { kind => 'default restored' })
    end
    old&.purge_later
    render json: workspace
  end

  def audit
    page = [[params.fetch(:page, 1).to_i, 1].max, 10000].min
    scope = SystemSettingAudit.order(id: :desc)
    render json: { entries: scope.offset((page - 1) * 20).limit(20).as_json(only: %i[id actor_name action changeset revision created_at]), meta: { page: page, total: scope.count, total_pages: (scope.count / 20.0).ceil } }
  end

  def snapshots
    render json: SystemSettingSnapshot.includes(:created_by).order(id: :desc).limit(30).map { |snapshot| snapshot_json(snapshot) }
  end

  def create_snapshot
    label = params[:label].to_s.strip.presence || "Configuration backup #{Time.current.utc.iso8601}"
    snapshot = nil
    setting.with_lock do
      return conflict unless current_revision?
      snapshot = backup(label)
      record_audit('backup.created', { snapshot_id: snapshot.id })
    end
    render json: snapshot_json(snapshot), status: :created
  end

  def download_snapshot
    snapshot = SystemSettingSnapshot.find(params[:id])
    send_data JSON.pretty_generate(snapshot.document), type: 'application/json', filename: "nishiohub-settings-#{snapshot.id}.json", disposition: 'attachment'
  end

  def restore
    return render_error('Type RESTORE to confirm', :unprocessable_entity) unless params[:confirmation] == 'RESTORE'
    document = params[:document]
    unless document.is_a?(ActionController::Parameters) && document[:format] == 'nishiohub-system-settings' && document[:schema_version] == 1 && document[:values].is_a?(ActionController::Parameters)
      return render_error('Choose a NishioHub configuration backup (schema version 1)', :unprocessable_entity)
    end
    values = document[:values].to_unsafe_h
    return render_error('Backup checksum does not match its contents', :unprocessable_entity) unless document[:checksum] == SystemSettingSnapshot.digest(values)

    apply_values(values, 'settings.restored', restoring: true)
  end

  def test_email
    return render_error('Email is not configured on the server', :unprocessable_entity) unless SystemSetting.mail_configured?

    PlatformMailer.with(user: current_user, platform_name: setting.config['platform_name']).test_email.deliver_now
    record_audit('email.test_sent', {})
    render json: { detail: 'Test email sent to your account email address' }
  rescue Net::SMTPError, IOError, SystemCallError, Timeout::Error
    render_error('Email delivery failed. Check the server mail configuration.', :service_unavailable)
  end

  private

  def setting
    @setting ||= SystemSetting.current
  end

  def current_revision?
    params[:lock_version].to_s.match?(/\A\d+\z/) && params[:lock_version].to_i == setting.lock_version
  end

  def conflict
    render_error('Settings changed since you opened this page. Reload the latest version before saving.', :conflict)
  end

  def apply_values(values, action, restoring: false)
    setting.with_lock do
      return conflict unless current_revision?
      before = setting.config
      candidate = restoring ? SystemSetting::DEFAULTS.merge(values) : before.merge(values)
      setting.values = candidate
      raise ActiveRecord::RecordInvalid, setting unless setting.valid?
      changes = candidate.each_with_object({}) { |(key, value), memo| memo[key] = { before: before[key], after: value } unless value == before[key] }
      if changes.any? || restoring
        backup('Before configuration restore') if restoring
        setting.updated_by = current_user
        setting.updated_at = Time.current if restoring
        setting.save!
        record_audit(action, changes)
      end
    end
    render json: workspace
  end

  def record_audit(action, changeset)
    SystemSettingAudit.create!(actor: current_user, actor_name: current_user.full_name, action: action, changeset: changeset, revision: setting.lock_version)
  end

  def backup(label)
    # Use persisted values, including during a pending restore.
    values = SystemSetting::DEFAULTS.merge(setting.values_in_database)
    SystemSettingSnapshot.create!(created_by: current_user, label: label, values: values,
      checksum: SystemSettingSnapshot.digest(values), revision: setting.lock_version)
  end

  def snapshot_json(snapshot)
    snapshot.as_json(only: %i[id label checksum revision created_at]).merge(created_by: snapshot.created_by&.full_name)
  end

  def assets
    { logo_url: branding_url(setting.logo), favicon_url: branding_url(setting.favicon),
      favicon_content_type: setting.favicon.attached? ? setting.favicon.blob.content_type : nil }
  end

  def branding_url(attachment)
    # Public branding needs stable URLs, independent of expiring storage-service links.
    rails_storage_proxy_path(attachment.blob, only_path: true) if attachment.attached?
  end

  def workspace
    { settings: setting.config, defaults: SystemSetting::DEFAULTS, lock_version: setting.lock_version, assets: assets,
      updated_at: setting.updated_at.iso8601, updated_by: setting.updated_by&.full_name,
      runtime: { environment: Rails.env, email_configured: SystemSetting.mail_configured?, storage: Rails.application.config.active_storage.service.to_s,
        database: ActiveRecord::Base.connection.active? ? 'connected' : 'unavailable', calendar: 'ics', backup_scope: 'configuration' } }
  end
end
