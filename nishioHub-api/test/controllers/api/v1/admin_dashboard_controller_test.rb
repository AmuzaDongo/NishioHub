require 'test_helper'
class Api::V1::AdminDashboardControllerTest < ActionDispatch::IntegrationTest
  ROOT = '/api/v1/admin/dashboard'
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'dash-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'dash-super@example.test')
    @mentee = create_mentee
    @mentor = create_mentor
    @service = create_service(mentor: @mentor)
    @headers = auth_headers(@admin)
  end
  def create_record(type, data)
    key = { programs: :program, sessions: :session, events: :event, resources: :resource }.fetch(type)
    post "#{ROOT}/#{type}", headers: @headers, params: { key => data }, as: :json
  end
  def session_data(**changes)
    { service_id: @service.id, mentee_id: @mentee.id, scheduled_at: 2.days.from_now.iso8601 }.merge(changes)
  end
  test 'reads and mutations enforce administrator permissions' do
    get ROOT
    assert_response :unauthorized
    get ROOT, headers: auth_headers(@mentee)
    assert_response :forbidden
    [@admin, @super].each do |actor|
      get ROOT, headers: auth_headers(actor)
      assert_response :ok
      assert_equal 'no-store', response.headers['Cache-Control']
      assert_equal 5, response.parsed_body['metrics'].size
      assert_not_includes response.body, 'hashed_password'
    end
    @admin.role.update!(permissions: ['dashboard.read'])
    get ROOT, headers: @headers
    assert_response :ok
    assert_not response.parsed_body.dig('capabilities', 'manage')
    create_record :programs, { title: 'Denied' }
    assert_response :forbidden
    get "#{ROOT}/options", headers: @headers
    assert_response :forbidden
    @admin.role.update!(permissions: ['users.read'])
    get ROOT, headers: @headers
    assert_response :forbidden
    get ROOT, headers: auth_headers(@super)
    assert_response :ok
  end
  test 'report uses local date boundaries real totals and exclusive role distribution' do
    travel_to Time.iso8601('2026-11-09T09:00:00Z') do
      User.update_all(created_at: Time.iso8601('2026-10-01T00:00:00Z'))
      @mentee.reload.update_columns(created_at: Time.iso8601('2026-11-08T21:30:00Z'))
      @mentee.additional_roles << @mentor.role
      get ROOT, headers: @headers, params: { period: 'custom', from: '2026-11-09', to: '2026-11-09' }
      assert_response :ok
      data = response.parsed_body
      assert_equal 'Africa/Kampala', data.dig('period', 'timezone')
      assert_equal [{ 'date' => '2026-11-09', 'users' => User.count }], data['growth']
      assert_equal User.count, data['distribution'].sum { |item| item['count'] }
      assert_equal 1, data.dig('insights', 'new_users')
      assert_nil data.dig('insights', 'user_growth')
      assert_equal 2, data['metrics'].find { |item| item['key'] == 'mentors' }['value']
      assert_nil data.dig('insights', 'session_rating')
    end
  end
  test 'invalid reporting windows are rejected' do
    tomorrow = (Time.current.in_time_zone(SystemSetting.config['timezone']).to_date + 1).iso8601
    [{ period: '0' }, { period: '30junk' }, { period: 'custom', from: '2025-01-01', to: '2026-11-09' }, { period: 'custom', from: 'bad', to: 'bad' }, { period: 'custom', from: tomorrow, to: tomorrow }].each do |params|
      get ROOT, headers: @headers, params: params
      assert_response :unprocessable_entity
    end
  end
  test 'health distinguishes actual probes from unmonitored services' do
    get "#{ROOT}/health", headers: @headers
    assert_response :ok
    checks = response.parsed_body['checks']
    assert_equal 'ok', checks.find { |item| item['key'] == 'database' }['status']
    %w[jobs email].each { |key| assert_equal 'unknown', checks.find { |item| item['key'] == key }['status'] }
    assert_not_includes response.body, '99.9'
    assert_includes response.parsed_body['uptime_scope'], 'Current API process'
  end
  test 'program edits detect stale versions and membership removal retains history' do
    create_record :programs, { title: 'Software Development', participant_ids: [@mentee.id, @mentor.id], created_by_id: @mentee.id }
    assert_response :created
    item = response.parsed_body
    program = PlatformProgram.find(item['id'])
    assert_equal @admin.id, program.created_by_id
    assert_equal 2, item['member_count']
    patch "#{ROOT}/programs/#{program.id}", headers: @headers, params: { program: { title: 'Updated Program', lock_version: item['lock_version'] } }, as: :json
    assert_response :ok
    patch "#{ROOT}/programs/#{program.id}", headers: @headers, params: { program: { title: 'Stale', lock_version: item['lock_version'] } }, as: :json
    assert_response :conflict
    get "#{ROOT}/programs/#{program.id}/members", headers: @headers
    assert_response :ok
    assert_equal 2, response.parsed_body.dig('meta', 'total')
    delete "#{ROOT}/programs/#{program.id}/members/#{@mentee.id}", headers: @headers
    assert_response :no_content
    assert_equal 2, program.program_memberships.count
    assert_equal 1, program.program_memberships.active.count
    post "#{ROOT}/programs/#{program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :ok
    assert_equal 2, program.program_memberships.active.count
    assert AdministrationAudit.exists?(target_id: program.id, action: 'program.members_added')
    post "#{ROOT}/programs/#{program.id}/members", headers: @headers, params: { user_ids: [@super.id] }, as: :json
    assert_response :unprocessable_entity
  end
  test 'lists paginate persisted data and reject unsupported filters' do
    21.times { |i| PlatformProgram.create!(title: "Program #{i}") }
    get "#{ROOT}/records", headers: @headers, params: { type: 'programs', page: 2 }
    assert_response :ok
    assert_equal 1, response.parsed_body['items'].size
    assert_equal 21, response.parsed_body.dig('meta', 'total')
    get "#{ROOT}/records", headers: @headers, params: { type: 'resources', status: 'garbage' }
    assert_response :unprocessable_entity
    get "#{ROOT}/records", headers: @headers, params: { type: 'users' }
    assert_response :unprocessable_entity
  end
  test 'sessions confirm without processing payments and prevent overlapping bookings' do
    starts = 2.days.from_now.change(usec: 0)
    create_record :sessions, session_data(scheduled_at: starts.iso8601)
    assert_response :created
    item = response.parsed_body
    booking = Booking.find(item['id'])
    assert_equal 'confirmed', booking.status
    assert_equal 'pending', booking.payment_status
    assert_equal @service.price, booking.total_price
    create_record :sessions, session_data(scheduled_at: (starts + 30.minutes).iso8601)
    assert_response :unprocessable_entity
    assert_equal 1, Booking.count
    create_record :sessions, session_data(scheduled_at: (starts + 1.hour).iso8601)
    assert_response :created
    patch "#{ROOT}/sessions/#{item['id']}", headers: @headers, params: { session: { status: 'completed', updated_at: item['updated_at'] } }, as: :json
    assert_response :unprocessable_entity
    patch "#{ROOT}/sessions/#{item['id']}", headers: @headers, params: { session: { status: 'cancelled', updated_at: 'stale' } }, as: :json
    assert_response :conflict
    patch "#{ROOT}/sessions/#{item['id']}", headers: @headers, params: { session: { status: 'cancelled', updated_at: item['updated_at'] } }, as: :json
    assert_response :ok
    assert_equal 'cancelled', booking.reload.status
  end
  test 'private sessions require eligible participants and active program membership' do
    program = PlatformProgram.create!(title: 'Career Development')
    data = session_data(service_id: nil, mentor_id: @mentor.id, title: 'Private guidance', category_id: @service.category_id, duration: 45, price: 0, platform_program_id: program.id)
    assert_no_difference 'Service.count' do
      create_record :sessions, data
      assert_response :unprocessable_entity
    end
    program.program_memberships.create!(user: @mentee)
    create_record :sessions, data
    assert_response :created
    booking = Booking.find(response.parsed_body['id'])
    assert_not booking.service.is_active?
    assert_equal program.id, booking.platform_program_id
    assert_equal 0, booking.total_price
    create_record :sessions, data.merge(scheduled_at: 4.days.from_now.iso8601, mentee_id: @super.id)
    assert_response :unprocessable_entity
  end
  test 'scheduling obeys global pause and explicit future timestamps' do
    create_record :sessions, session_data(scheduled_at: 2.days.ago.iso8601)
    assert_response :unprocessable_entity
    create_record :sessions, session_data(scheduled_at: 2.days.from_now.strftime('%Y-%m-%dT%H:%M:%S'))
    assert_response :unprocessable_entity
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS.merge('matching_enabled' => false))
    create_record :sessions, session_data
    assert_response :forbidden
    assert_equal 0, Booking.count
  end
  test 'events cannot shrink below registrations or overwrite a newer version' do
    create_record :events, { title: 'Career pathways', description: 'Meet mentors and learn.', category: 'talk', location: 'Online', starts_at: 2.days.from_now.iso8601, ends_at: (2.days.from_now + 1.hour).iso8601 }
    assert_response :created
    item = response.parsed_body
    event = Event.find(item['id'])
    event.event_registrations.create!(user: @mentee, status: 'registered')
    event.event_registrations.create!(user: create_mentee(email: 'second@example.test'), status: 'registered')
    patch "#{ROOT}/events/#{event.id}", headers: @headers, params: { event: { capacity: 1, updated_at: item['updated_at'] } }, as: :json
    assert_response :unprocessable_entity
    patch "#{ROOT}/events/#{event.id}", headers: @headers, params: { event: { title: 'New title', updated_at: item['updated_at'] } }, as: :json
    assert_response :ok
    patch "#{ROOT}/events/#{event.id}", headers: @headers, params: { event: { title: 'Stale', updated_at: item['updated_at'] } }, as: :json
    assert_response :conflict
    get ROOT, headers: @headers
    assert_equal 2, response.parsed_body['upcoming_events'].find { |record| record['id'] == event.id }['registrations']
  end
  test 'resource downloads require authentication and drafts are hidden from members' do
    upload = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/notes.txt'), 'text/plain')
    post "#{ROOT}/resources", headers: @headers, params: { resource: { title: 'Practical guide', published: 'false', file: upload } }
    assert_response :created
    item = response.parsed_body
    resource = PlatformResource.find(item['id'])
    assert resource.file.attached?
    get "/api/v1/learning/resources/#{resource.id}/file"
    assert_response :unauthorized
    get "/api/v1/learning/resources/#{resource.id}/file", headers: auth_headers(@mentee)
    assert_response :not_found
    get "/api/v1#{item.dig('file', 'download_path')}", headers: @headers
    assert_response :ok
    assert_includes response.headers['Content-Disposition'], 'notes.txt'
    patch "#{ROOT}/resources/#{resource.id}", headers: @headers, params: { resource: { published: true, lock_version: item['lock_version'] } }, as: :json
    assert_response :ok
    get '/api/v1/me/learning_area', headers: auth_headers(@mentee)
    assert_response :ok
    assert_includes response.parsed_body['shared_resources'].map { |record| record['id'] }, resource.id
    get "/api/v1/learning/resources/#{resource.id}/file", headers: auth_headers(@mentee)
    assert_response :ok
    patch "#{ROOT}/resources/#{resource.id}", headers: @headers, params: { resource: { title: 'Stale', lock_version: item['lock_version'] } }, as: :json
    assert_response :conflict
  end
  test 'resources validate content URL and publish flag' do
    [{ title: 'Empty' }, { title: 'Unsafe', url: 'javascript:alert(1)' }, { title: 'Unsafe', url: 'https://user:pass@example.com' }, { title: 'Invalid flag', url: 'https://example.com', published: 'no' }].each do |data|
      create_record :resources, data
      assert_response :unprocessable_entity
    end
    create_record :resources, { title: 'Valid guide', url: 'https://example.com/guide', published: true }
    assert_response :created
  end
  test 'search and activity only expose authorized operational summaries' do
    PlatformProgram.create!(title: 'Unique dashboard program')
    get "#{ROOT}/search", headers: @headers, params: { q: 'Unique dashboard' }
    assert_response :ok
    assert_equal 'program', response.parsed_body.first['kind']
    get "#{ROOT}/records", headers: @headers, params: { type: 'activities' }
    assert_response :ok
    assert_includes response.parsed_body['items'].map { |record| record['kind'] }, 'program'
    assert_not_includes response.body, @admin.email
    @admin.role.update!(permissions: ['dashboard.read'])
    get "#{ROOT}/search", headers: @headers, params: { q: @mentor.full_name }
    assert_response :ok
    assert_not response.parsed_body.any? { |item| item['kind'] == 'user' }
  end
  test 'report counts only sessions and events scheduled in range and completed session reviews' do
    travel_to Time.iso8601('2026-11-09T09:00:00Z') do
      booking = create_booking(service: @service, mentee: @mentee, mentor: @mentor, status: 'completed', scheduled_at: 2.days.ago)
      booking.create_review!(service: @service, mentor: @mentor, mentee: @mentee, rating: 4, comment: 'Helpful guidance')
      create_booking(service: @service, mentee: @mentee, mentor: @mentor, status: 'cancelled', scheduled_at: 3.days.ago)
      create_booking(service: @service, mentee: @mentee, mentor: @mentor, scheduled_at: 2.days.from_now)
      MenteeGoal.create!(user: @mentee, title: 'Learn basics', completed: true, progress: 100)
      MenteeGoal.create!(user: @mentee, title: 'Practice skills', completed: false, progress: 20)
      get ROOT, headers: @headers, params: { period: '7' }
      assert_response :ok
      assert_equal 1, response.parsed_body['metrics'].find { |item| item['key'] == 'sessions' }['value']
      assert_equal 4.0, response.parsed_body.dig('insights', 'session_rating')
      assert_equal 1, response.parsed_body.dig('insights', 'review_count')
      assert_equal 50.0, response.parsed_body.dig('insights', 'goal_completion')
      get "#{ROOT}/records", headers: @headers, params: { type: 'sessions', window: 'period', period: '7', status: 'completed' }
      assert_response :ok
      assert_equal [booking.id], response.parsed_body['items'].map { |item| item['id'] }
    end
  end
  test 'overlap protection follows participants across mentor and mentee roles' do
    @mentor.additional_roles << @mentee.role
    other_mentor = create_mentor(email: 'other-mentor@example.test')
    other_service = create_service(mentor: other_mentor)
    starts = 2.days.from_now.change(usec: 0)
    create_booking(service: other_service, mentee: @mentor, mentor: other_mentor, scheduled_at: starts)
    create_record :sessions, session_data(scheduled_at: starts.iso8601)
    assert_response :unprocessable_entity
    assert_equal 1, Booking.count
  end
  test 'members are paginated and active ranking excludes removed memberships' do
    program = PlatformProgram.create!(title: 'Ranked program')
    program.program_memberships.create!(user: @mentor, is_active: false)
    21.times do |index|
      person = create_mentee(email: "member-#{index}@example.test")
      program.program_memberships.create!(user: person)
    end
    get "#{ROOT}/programs/#{program.id}/members", headers: @headers, params: { page: 2 }
    assert_response :ok
    assert_equal 1, response.parsed_body['items'].size
    assert_equal 21, response.parsed_body.dig('meta', 'total')
    get ROOT, headers: @headers
    assert_response :ok
    assert_equal 21, response.parsed_body['top_programs'].first['members']
  end
  test 'resource upload rejects unsupported content and follows the platform file cap' do
    file = Tempfile.new(['resource-test', '.html'])
    file.write('<html><script>alert(1)</script></html>')
    file.flush
    upload = Rack::Test::UploadedFile.new(file.path, 'text/html')
    post "#{ROOT}/resources", headers: @headers, params: { resource: { title: 'Invalid HTML', file: upload } }
    assert_response :unprocessable_entity
    file.close!
    file = Tempfile.new(['resource-cap', '.txt'])
    file.write('A' * (1.megabyte + 1))
    file.flush
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS.merge('max_upload_mb' => 1))
    upload = Rack::Test::UploadedFile.new(file.path, 'text/plain')
    post "#{ROOT}/resources", headers: @headers, params: { resource: { title: 'Oversized text', file: upload } }
    assert_response :unprocessable_entity
    assert_equal 0, PlatformResource.count
    file.close!
  end

end
