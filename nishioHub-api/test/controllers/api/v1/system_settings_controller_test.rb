require 'test_helper'

class Api::V1::SystemSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
  end

  def person(role = 'admin', email = "system-#{role}@example.test")
    User.create!(full_name: "System #{role}", email: email, password: 'SystemPass123', role: create_role(role),
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}")
  end

  def change(user, values, revision = SystemSetting.current.lock_version)
    patch '/api/v1/admin/system_settings', headers: auth_headers(user), params: { settings: values, lock_version: revision }, as: :json
  end

  test 'settings audit backups branding and email require admin or super admin' do
    get '/api/v1/admin/system_settings'
    assert_response :unauthorized
    %w[mentee mentor moderator organization].each do |role|
      user = person(role)
      get '/api/v1/admin/system_settings', headers: auth_headers(user)
      assert_response :forbidden
      change(user, platform_name: 'Denied')
      assert_response :forbidden
      get '/api/v1/admin/system_settings/audit', headers: auth_headers(user)
      assert_response :forbidden
      get '/api/v1/admin/system_settings/backups', headers: auth_headers(user)
      assert_response :forbidden
      post '/api/v1/admin/system_settings/assets/logo', headers: auth_headers(user)
      assert_response :forbidden
      post '/api/v1/admin/system_settings/test-email', headers: auth_headers(user)
      assert_response :forbidden
    end
    %w[admin super_admin].each do |role|
      user = person(role)
      get '/api/v1/admin/system_settings', headers: auth_headers(user)
      assert_response :ok
      change(user, platform_name: "#{role} platform")
      assert_response :ok
    end
  end

  test 'public config exposes only safe branding and public event controls' do
    user = person
    change(user, platform_name: 'School Hub', support_email: 'help@example.test', password_min_length: 12)
    assert_response :ok
    get '/api/v1/platform/config'
    assert_response :ok
    assert_equal 'School Hub', response.parsed_body['platform_name']
    assert_equal 'help@example.test', response.parsed_body['support_email']
    assert_not_includes response.body, 'access_token_minutes'
    assert_not_includes response.body, 'SMTP_PASSWORD'
    assert_not_includes response.body, 'updated_by'
    change(user, public_events_enabled: false)
    get '/api/v1/platform/events'
    assert_response :ok
    assert_equal [], response.parsed_body
  end

  test 'public events can be enabled and never expose meeting links or attendee details' do
    admin = person
    Event.create!(organizer: admin, title: 'Public Career Talk', description: 'Learn about careers', category: 'talk', location: 'Online', meeting_url: 'https://zoom.us/private-meeting', starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)
    get '/api/v1/platform/events'
    assert_equal [], response.parsed_body
    change(admin, public_events_enabled: true)
    get '/api/v1/platform/events'
    assert_response :ok
    assert_includes response.parsed_body.map { |event| event['title'] }, 'Public Career Talk'
    assert_not_includes response.body, 'private-meeting'
    assert_not_includes response.body, 'organizer_id'
  end

  test 'email verification cannot be enabled without configured delivery' do
    admin = person
    original = SystemSetting.method(:mail_configured?)
    begin
      SystemSetting.define_singleton_method(:mail_configured?) { false }
      change(admin, require_email_verification: true)
      assert_response :unprocessable_entity
      assert_equal false, SystemSetting.config['require_email_verification']
    ensure
      SystemSetting.define_singleton_method(:mail_configured?, original)
    end
  end

  test 'validated atomic updates record the actor and changed fields and reject stale revisions' do
    user = person
    revision = SystemSetting.current.lock_version
    initial_audits = SystemSettingAudit.count
    change(user, { platform_name: 'Saved Hub', timezone: 'Africa/Nairobi' }, revision)
    assert_response :ok
    saved_revision = response.parsed_body['lock_version']
    assert saved_revision > revision
    assert_equal user.full_name, response.parsed_body['updated_by']
    audit = SystemSettingAudit.order(:id).last
    assert_equal user.id, audit.actor_id
    assert_equal 'Saved Hub', audit.changeset.dig('platform_name', 'after')
    change(user, { platform_name: 'Stale' }, revision)
    assert_response :conflict
    assert_equal 'Saved Hub', SystemSetting.config['platform_name']
    change(user, { platform_name: 'Not Saved', timezone: 'Invalid/Zone', registration_enabled: 'true', secret: 'denied' }, saved_revision)
    assert_response :unprocessable_entity
    assert_equal 'Saved Hub', SystemSetting.config['platform_name']
    assert_equal initial_audits + 1, SystemSettingAudit.count
    assert_equal 'no-store', response.headers['Cache-Control']
  end

  test 'registration switch default role password policy and role escalation are enforced' do
    admin = person
    change(admin, registration_enabled: false)
    post '/api/v1/auth/register', params: { full_name: 'Closed', email: 'closed@example.test', phone_number: '+256700001001', password: 'LongPassword123' }, as: :json
    assert_response :forbidden
    change(admin, registration_enabled: true, default_registration_role: 'mentor', password_min_length: 12)
    post '/api/v1/auth/register', params: { full_name: 'Weak', email: 'weak@example.test', phone_number: '+256700001002', password: 'short' }, as: :json
    assert_response :unprocessable_entity
    post '/api/v1/auth/register', params: { full_name: 'Escalated', email: 'escalate@example.test', phone_number: '+256700001003', password: 'LongPassword123', role_id: admin.role_id }, as: :json
    assert_response :bad_request
    post '/api/v1/auth/register', params: { full_name: 'New Mentor', email: 'newmentor@example.test', phone_number: '+256700001004', password: 'LongPassword123' }, as: :json
    assert_response :ok
    assert_equal 'mentor', response.parsed_body.dig('role', 'name')
  end

  test 'maintenance blocks nonstaff APIs and login while allowing both administrator roles to recover' do
    admin = person
    super_admin = person('super_admin')
    learner = person('mentee')
    change(admin, platform_mode: 'maintenance', maintenance_message: 'Planned maintenance')
    assert_response :ok
    get '/api/v1/users/me', headers: auth_headers(learner)
    assert_response :service_unavailable
    assert_equal '300', response.headers['Retry-After']
    post '/api/v1/auth/login', params: { email: learner.email, password: 'SystemPass123' }, as: :json
    assert_response :service_unavailable
    get '/api/v1/platform/config'
    assert_response :ok
    assert_equal 'maintenance', response.parsed_body['platform_mode']
    [admin, super_admin].each do |staff|
      post '/api/v1/auth/login', params: { email: staff.email, password: 'SystemPass123' }, as: :json
      assert_response :ok
      get '/api/v1/admin/system_settings', headers: auth_headers(staff)
      assert_response :ok
    end
    change(super_admin, platform_mode: 'live')
    assert_response :ok
    get '/api/v1/users/me', headers: auth_headers(learner)
    assert_response :ok
  end

  test 'session policies apply to new access and refresh tokens' do
    admin = person
    change(admin, access_token_minutes: 15, refresh_token_days: 2)
    post '/api/v1/auth/login', params: { email: admin.email, password: 'SystemPass123' }, as: :json
    assert_response :ok
    tokens = response.parsed_body
    access = JsonWebToken.decode(tokens['access_token'])
    refresh = JsonWebToken.decode(tokens['refresh_token'])
    assert_in_delta 15.minutes.from_now.to_i, access['exp'], 3
    assert_in_delta 2.days.from_now.to_i, refresh['exp'], 3
  end

  test 'notification and enrollment feature switches stop new work and preserve history' do
    admin = person
    learner = person('mentee')
    learner.notifications.create!(title: 'Existing Alert', message: 'Keep history')
    change(admin, notifications_enabled: false, matching_enabled: false, learning_enrollment_enabled: false, event_registration_enabled: false)
    Notification.deliver(user: learner, source_key: 'blocked', title: 'Blocked', message: 'New', category: 'system', topic: 'platform', icon: 'bell', href: '/notifications')
    assert_equal 1, learner.notifications.count
    post '/api/v1/notifications', headers: auth_headers(learner), params: { title: 'Paused', message: 'No new alerts' }, as: :json
    assert_response :forbidden
    post '/api/v1/bookings', headers: auth_headers(learner), params: {}, as: :json
    assert_response :forbidden
    course = LearningCatalog.courses.first
    post "/api/v1/me/learning_area/#{course['id']}/enroll", headers: auth_headers(learner)
    assert_response :forbidden
    event = Event.create!(organizer: admin, title: 'Workshop', description: 'Learn together', category: 'workshop', location: 'School', starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)
    post "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner)
    assert_response :forbidden
    assert_empty learner.event_registrations
  end

  test 'email verification sends a real test transport message and verifies before login' do
    admin = person
    ActionMailer::Base.deliveries.clear
    change(admin, require_email_verification: true)
    assert_response :ok
    post '/api/v1/auth/register', params: { full_name: 'Verify Learner', email: 'verify-system@example.test', phone_number: '+256700001005', password: 'LongPassword123' }, as: :json
    assert_response :ok
    assert response.parsed_body['verification_required']
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal ['verify-system@example.test'], ActionMailer::Base.deliveries.last.to
    learner = User.find_by!(email: 'verify-system@example.test')
    post '/api/v1/auth/login', params: { email: learner.email, password: 'LongPassword123' }, as: :json
    assert_response :forbidden
    get '/api/v1/users/verify-email', params: { token: EmailToken.encode(learner.email) }
    assert_response :ok
    post '/api/v1/auth/login', params: { email: learner.email, password: 'LongPassword123' }, as: :json
    assert_response :ok
    post '/api/v1/admin/system_settings/test-email', headers: auth_headers(admin), params: { recipient: 'not-allowed@example.test' }, as: :json
    assert_response :ok
    assert_equal [admin.email], ActionMailer::Base.deliveries.last.to
  end

  test 'branding upload removal and global upload cap validate files' do
    admin = person
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/avatar.png'), 'image/png')
    post '/api/v1/admin/system_settings/assets/logo', headers: auth_headers(admin), params: { file: file, lock_version: SystemSetting.current.lock_version }
    assert_response :ok
    assert response.parsed_body.dig('assets', 'logo_url').present?
    revision = response.parsed_body['lock_version']
    post '/api/v1/admin/system_settings/assets/logo', headers: auth_headers(admin), params: { file: 'signed-blob-string', lock_version: revision }, as: :json
    assert_response :unprocessable_entity
    delete '/api/v1/admin/system_settings/assets/logo', headers: auth_headers(admin), params: { lock_version: revision }, as: :json
    assert_response :ok
    assert_nil response.parsed_body.dig('assets', 'logo_url')
    change(admin, max_upload_mb: 1)
    Tempfile.create(['oversized-system', '.txt']) do |temp|
      temp.write('a' * (1.megabyte + 1)); temp.flush
      post '/api/v1/conversations', headers: auth_headers(admin), params: { file: Rack::Test::UploadedFile.new(temp.path, 'text/plain') }
      assert_response :unprocessable_entity
      assert_includes response.parsed_body['detail'], '1 MB'
    end
  end

  test 'meeting provider allowlist is enforced without accepting suffix lookalikes' do
    admin = person
    change(admin, allowed_meeting_hosts: ['zoom.us', 'meet.google.com'])
    event = Event.new(organizer: admin, title: 'Meeting', description: 'Learning', category: 'mentorship', location: 'Online', starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)
    event.meeting_url = 'https://us06web.zoom.us/j/123'
    assert event.valid?
    event.meeting_url = 'https://zoom.us.attacker.example/j/123'
    assert_not event.valid?
    change(admin, allowed_meeting_hosts: ['https://zoom.us'])
    assert_response :unprocessable_entity
  end

  test 'configuration snapshots export restore and automatically preserve previous settings' do
    admin = person
    change(admin, platform_name: 'Original Config')
    post '/api/v1/admin/system_settings/backups', headers: auth_headers(admin), params: { lock_version: SystemSetting.current.lock_version, label: 'Before edits' }, as: :json
    assert_response :created
    id = response.parsed_body['id']
    get "/api/v1/admin/system_settings/backups/#{id}", headers: auth_headers(admin)
    assert_response :ok
    document = JSON.parse(response.body)
    assert_equal 'Original Config', document.dig('values', 'platform_name')
    assert_not_includes response.body, 'hashed_password'
    change(admin, platform_name: 'New Config')
    post '/api/v1/admin/system_settings/restore', headers: auth_headers(admin), params: { document: document, confirmation: 'RESTORE', lock_version: SystemSetting.current.lock_version }, as: :json
    assert_response :ok
    assert_equal 'Original Config', SystemSetting.config['platform_name']
    assert_equal 'New Config', SystemSettingSnapshot.order(:id).last.values['platform_name']
    assert_equal 'settings.restored', SystemSettingAudit.order(:id).last.action
    document['values']['platform_name'] = 'Tampered'
    post '/api/v1/admin/system_settings/restore', headers: auth_headers(admin), params: { document: document, confirmation: 'RESTORE', lock_version: SystemSetting.current.lock_version }, as: :json
    assert_response :unprocessable_entity
    assert_equal 'Original Config', SystemSetting.config['platform_name']
  end

  test 'restore rejects stale revisions unconfirmed and invalid settings even with valid checksum' do
    admin = person
    initial_backups = SystemSettingSnapshot.count
    document = { format: 'nishiohub-system-settings', schema_version: 1, values: SystemSetting.config.merge('access_token_minutes' => -1) }
    document[:checksum] = SystemSettingSnapshot.digest(document[:values])
    post '/api/v1/admin/system_settings/restore', headers: auth_headers(admin), params: { document: document, confirmation: 'RESTORE', lock_version: SystemSetting.current.lock_version }, as: :json
    assert_response :unprocessable_entity
    assert_equal initial_backups, SystemSettingSnapshot.count
    assert_equal 60, SystemSetting.config['access_token_minutes']
    document[:values] = SystemSetting.config
    document[:checksum] = SystemSettingSnapshot.digest(document[:values])
    post '/api/v1/admin/system_settings/restore', headers: auth_headers(admin), params: { document: document, confirmation: 'NO', lock_version: SystemSetting.current.lock_version }, as: :json
    assert_response :unprocessable_entity
    post '/api/v1/admin/system_settings/restore', headers: auth_headers(admin), params: { document: document, confirmation: 'RESTORE', lock_version: 90000 }, as: :json
    assert_response :conflict
  end
end
