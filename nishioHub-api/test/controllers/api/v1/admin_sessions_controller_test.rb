require 'test_helper'
require 'csv'
class Api::V1::AdminSessionsControllerTest < ActionDispatch::IntegrationTest
  ROOT = '/api/v1/admin/sessions'
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'sessions-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'sessions-super@example.test')
    @mentor = create_mentor
    @mentee = create_mentee
    @second = create_mentee(email: 'second-session@example.test', full_name: 'Second Learner')
    @service = create_service(mentor: @mentor)
    @headers = auth_headers(@admin)
    @program = PlatformProgram.create!(title: 'Science Program', starts_on: Date.current, ends_on: Date.current + 90)
    [@mentee, @second].each { |u| @program.program_memberships.create!(user: u) }
  end
  def body = response.parsed_body
  def draft(**changes)
    { title: 'Data Science Workshop', description: 'Build practical projects', mentor_id: @mentor.id, mentee_ids: [@mentee.id, @second.id], category_id: @service.category_id, program_id: @program.id,
      scheduled_at: 2.days.from_now.change(hour: 10).iso8601, duration: 60, format: 'online', location: '', meeting_url: 'https://example.com/meeting' }.merge(changes)
  end
  def schedule_session(**changes)
    post ROOT, headers: @headers, params: { session: draft(**changes) }, as: :json
    assert_response :created
    Booking.find(body['id'])
  end
  def csv(rows)
    file = Tempfile.new(['session-import', '.csv'])
    file.write(CSV.generate { |out| out << AdminSessionImport::HEADERS; rows.each { |row| out << row } }); file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'text/csv')]
  end
  test 'admin and super admin access and read only permissions' do
    get ROOT
    assert_response :unauthorized
    [@mentor, @mentee].each { |u| get ROOT, headers: auth_headers(u); assert_response :forbidden }
    [@admin, @super].each do |u|
      get ROOT, headers: auth_headers(u)
      assert_response :ok
      assert_equal 'private, no-store', response.headers['Cache-Control']
      assert body.dig('capabilities', 'manage')
    end
    @admin.role.update!(permissions: ['dashboard.read'])
    get ROOT, headers: @headers
    assert_response :ok
    assert_not body.dig('capabilities', 'schedule')
    post ROOT, headers: @headers, params: { session: draft }, as: :json
    assert_response :forbidden
    @admin.role.update!(permissions: [])
    get ROOT, headers: @headers
    assert_response :forbidden
  end
  test 'legacy bookings register primary attendee and group sessions preserve underlying services and payments' do
    old = create_booking(service: @service, mentor: @mentor, mentee: @mentee, scheduled_at: 5.days.from_now)
    assert_equal [@mentee.id], old.booking_participants.pluck(:user_id)
    booking = schedule_session
    assert_equal 'confirmed', booking.status
    assert_equal 'pending', booking.payment_status
    assert_equal 0, booking.total_price
    assert_equal 2, booking.booking_participants.count
    assert_not booking.service.is_active?
    assert_equal 'Mentoring Session', @service.reload.title
    get "#{ROOT}/#{booking.id}", headers: @headers
    assert_response :ok
    assert_equal 'Data Science Workshop', body['title']
    assert_equal 2, body['attendees']
    assert_equal [@mentee.id, @second.id].sort, body['participants'].map { |p| p['id'] }.sort
    assert_not_includes response.body, @mentee.email
    assert_equal 1, @second.notifications.where(title: 'Mentorship Session Confirmed').count
    assert_equal 1, @mentor.notifications.where(source_key: "booking-#{booking.id}-confirmed").count
    get '/api/v1/bookings', headers: auth_headers(@second)
    assert_response :ok
    assert_includes body['bookings'].map { |b| b['id'] }, booking.id
    patch "/api/v1/bookings/#{booking.id}", headers: auth_headers(@second), params: { status: 'cancelled' }, as: :json
    assert_response :forbidden
  end
  test 'status tabs and aggregate charts use actual timestamps and attendance' do
    travel_to Time.zone.parse('2026-11-09 12:00:00') do
      future = create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'confirmed', scheduled_at: 2.days.from_now)
      ongoing = create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'confirmed', scheduled_at: 30.minutes.ago)
      completed = create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'completed', scheduled_at: 2.days.ago)
      completed.update!(platform_program: @program)
      completed.booking_participants.first.update!(attended: true, recorded_at: Time.current)
      create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'cancelled', scheduled_at: 3.days.ago)
      get ROOT, headers: @headers
      assert_response :ok
      assert_equal 4, body.dig('stats', 'total')
      assert_equal 1, body.dig('stats', 'completed')
      assert_equal 1, body.dig('stats', 'upcoming')
      assert_equal 3, body.dig('stats', 'attendees')
      assert_equal 1, body['trend'].sum { |v| v['attendance'] }
      assert_equal 4, body['distribution'].sum { |v| v['count'] }
      assert_equal @program.id, body['top_programs'].first['id']
      get ROOT, headers: @headers, params: { tab: 'ongoing' }
      assert_equal [ongoing.id], body['items'].map { |v| v['id'] }
      get ROOT, headers: @headers, params: { tab: 'upcoming' }
      assert_equal [future.id], body['items'].map { |v| v['id'] }
    end
  end
  test 'search program mentor format sort and pagination are applied on the server' do
    booking = schedule_session(format: 'on_site', location: 'Kampala')
    get ROOT, headers: @headers, params: { q: 'Second Learner', program_id: @program.id, mentor_id: @mentor.id, format: 'on_site', sort: 'title', direction: 'asc', per_page: 5 }
    assert_response :ok
    assert_equal [booking.id], body['items'].map { |r| r['id'] }
    get ROOT, headers: @headers, params: { q: 'not found' }
    assert_empty body['items']
    [{ tab: 'bogus' }, { format: 'bogus' }, { per_page: 999 }, { sort: 'drop' }, { months: '1' }, { program_id: 'x' }].each do |params|
      get ROOT, headers: @headers, params: params
      assert_response :unprocessable_entity
    end
    get ROOT, headers: @headers, params: { page: 2 }
    assert_empty body['items']
    assert_equal 1, body.dig('meta', 'total')
  end
  test 'scheduling validates membership accounts duration format time and safe URLs atomically' do
    invalid = [{ scheduled_at: 1.day.ago.iso8601 }, { scheduled_at: 2.days.from_now.strftime('%Y-%m-%dT%H:%M') }, { duration: 3 }, { duration: '30.5' },
      { mentor_id: @mentee.id }, { mentee_ids: [@admin.id] }, { mentee_ids: [] }, { format: 'unknown' }, { format: 'on_site', location: '' }, { meeting_url: 'javascript:alert(1)' }, { title: '' }]
    invalid.each do |change|
      post ROOT, headers: @headers, params: { session: draft(**change) }, as: :json
      assert_includes [404, 422], response.status
    end
    assert_equal 0, Booking.count
    @program.program_memberships.find_by!(user: @second).update!(is_active: false)
    post ROOT, headers: @headers, params: { session: draft }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, Booking.count
    post ROOT, headers: @headers, params: { session: draft(mentee_ids: [@mentee.id], scheduled_at: (@program.ends_on + 2).to_time.iso8601) }, as: :json
    assert_response :unprocessable_entity
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS.merge('matching_enabled' => false))
    post ROOT, headers: @headers, params: { session: draft(program_id: nil) }, as: :json
    assert_response :forbidden
  end
  test 'rescheduling preserves service snapshots detects stale revisions and conflicts for every attendee' do
    booking = schedule_session
    get "#{ROOT}/#{booking.id}", headers: @headers
    version = body['updated_at']
    patch "#{ROOT}/#{booking.id}", headers: @headers, params: { session: draft(title: 'Updated Title', updated_at: version, scheduled_at: 3.days.from_now.iso8601) }, as: :json
    assert_response :ok
    assert_equal 'Updated Title', body['title']
    assert_equal 'Data Science Workshop', booking.service.reload.title
    patch "#{ROOT}/#{booking.id}", headers: @headers, params: { session: draft(updated_at: version) }, as: :json
    assert_response :conflict
    other_mentor = create_mentor(email: 'other-session-mentor@example.test')
    post ROOT, headers: @headers, params: { session: draft(mentor_id: other_mentor.id, mentee_ids: [@second.id], scheduled_at: booking.reload.scheduled_at.iso8601) }, as: :json
    assert_response :unprocessable_entity
    assert BookingSchedule.conflict?(mentor_id: other_mentor.id, mentee_id: @second.id, starts_at: booking.scheduled_at, duration: 60)
    assert_not BookingSchedule.conflict?(mentor_id: other_mentor.id, mentee_id: @second.id, starts_at: booking.scheduled_at + 1.hour, duration: 60)
  end
  test 'status transitions enforce revisions and completion time and retain attendees' do
    booking = schedule_session
    patch "#{ROOT}/#{booking.id}/status", headers: @headers, params: { session: { status: 'completed', updated_at: booking.updated_at.iso8601(6) } }, as: :json
    assert_response :unprocessable_entity
    booking.update!(scheduled_at: 2.hours.ago)
    patch "#{ROOT}/#{booking.id}/status", headers: @headers, params: { session: { status: 'completed', updated_at: booking.updated_at.iso8601(6) } }, as: :json
    assert_response :ok
    assert_equal 'completed', booking.reload.status
    assert_equal 2, booking.booking_participants.count
    patch "#{ROOT}/#{booking.id}/status", headers: @headers, params: { session: { status: 'confirmed', updated_at: booking.updated_at.iso8601(6) } }, as: :json
    assert_response :unprocessable_entity
    patch "#{ROOT}/#{booking.id}", headers: @headers, params: { session: draft(updated_at: booking.updated_at.iso8601(6)) }, as: :json
    assert_response :unprocessable_entity
  end
  test 'attendance is scoped versioned nullable and only recorded after start' do
    booking = schedule_session; person = booking.booking_participants.first
    path = "#{ROOT}/#{booking.id}/participants/#{person.id}"
    patch path, headers: @headers, params: { attendance: { attended: true, updated_at: booking.updated_at.iso8601(6) } }, as: :json
    assert_response :unprocessable_entity
    booking.update!(scheduled_at: 30.minutes.ago)
    version = booking.updated_at.iso8601(6)
    patch path, headers: @headers, params: { attendance: { attended: true, updated_at: version } }, as: :json
    assert_response :no_content
    assert person.reload.attended
    assert person.recorded_at
    patch path, headers: @headers, params: { attendance: { attended: false, updated_at: version } }, as: :json
    assert_response :conflict
    patch path, headers: @headers, params: { attendance: { attended: nil, updated_at: booking.reload.updated_at.iso8601(6) } }, as: :json
    assert_response :no_content
    assert_nil person.reload.attended
    patch path, headers: @headers, params: { attendance: { attended: 'true', updated_at: booking.reload.updated_at.iso8601(6) } }, as: :json
    assert_response :unprocessable_entity
    patch "#{ROOT}/#{booking.id}/participants/99999", headers: @headers, params: { attendance: { attended: true, updated_at: booking.reload.updated_at.iso8601(6) } }, as: :json
    assert_response :not_found
    @admin.role.update!(permissions: ['dashboard.read'])
    patch path, headers: @headers, params: { attendance: { attended: true, updated_at: booking.updated_at.iso8601(6) } }, as: :json
    assert_response :forbidden
    get "#{ROOT}/#{booking.id}/participants", headers: @headers
    assert_response :ok
    assert_not_includes response.body, @mentee.email
  end
  test 'CSV export is filtered scoped and neutralizes spreadsheet formulas' do
    booking = schedule_session(title: '=FORMULA')
    get "#{ROOT}/export", headers: @headers, params: { session_ids: [booking.id], format: 'online' }
    assert_response :ok
    assert_includes response.media_type, 'text/csv'
    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.size
    assert_equal "'=FORMULA", rows.first['title']
    assert_not_includes response.body, @mentee.email
  end
  test 'CSV preview is read only and import checks overlapping rows and commits atomically' do
    values = draft
    row = AdminSessionImport::HEADERS.map { |h| h == 'mentee_ids' ? values[:mentee_ids].join(';') : values[h.to_sym] }
    file, uploaded = csv([row])
    post "#{ROOT}/import-preview", headers: @headers, params: { file: uploaded }
    assert_response :ok
    assert body['valid']
    assert_equal 0, Booking.count
    uploaded = Rack::Test::UploadedFile.new(file.path, 'text/csv')
    post "#{ROOT}/import", headers: @headers, params: { file: uploaded }
    assert_response :created
    assert_equal 1, Booking.count
    assert_equal 2, BookingParticipant.count
    file.close!
    new_row = row.dup; new_row[6] = 4.days.from_now.iso8601
    file, uploaded = csv([new_row, new_row])
    post "#{ROOT}/import", headers: @headers, params: { file: uploaded }
    assert_response :unprocessable_entity
    assert_not body['valid']
    assert_equal 1, Booking.count
    file.close!
  end
  test 'free mentor reassignment clones the offering and paid bookings retain their billing participants' do
    booking = schedule_session
    other = create_mentor(email: 'reassigned-session-mentor@example.test')
    original_service = booking.service_id
    patch "#{ROOT}/#{booking.id}", headers: @headers, params: { session: draft(mentor_id: other.id, updated_at: booking.updated_at.iso8601(6)) }, as: :json
    assert_response :ok
    assert_equal other.id, booking.reload.mentor_id
    assert_equal other.id, booking.service.mentor_id
    assert_not_equal original_service, booking.service_id
    assert_equal @mentor.id, Service.find(original_service).mentor_id
    paid = create_booking(service: @service, mentor: @mentor, mentee: @mentee, scheduled_at: 8.days.from_now)
    patch "#{ROOT}/#{paid.id}", headers: @headers, params: { session: draft(mentor_id: other.id, mentee_ids: [@mentee.id], program_id: nil, scheduled_at: paid.scheduled_at.iso8601, updated_at: paid.updated_at.iso8601(6)) }, as: :json
    assert_response :unprocessable_entity
    assert_equal @mentor.id, paid.reload.mentor_id
    assert_equal @service.id, paid.service_id
    patch "#{ROOT}/#{paid.id}", headers: @headers, params: { session: draft(mentee_ids: [@mentee.id], program_id: nil, title: 'Paid session new title', scheduled_at: paid.scheduled_at.iso8601, updated_at: paid.updated_at.iso8601(6)) }, as: :json
    assert_response :ok
    assert_equal @service.price, paid.reload.total_price
    assert_equal @service.id, paid.service_id
    assert_equal 'Mentoring Session', @service.reload.title
  end

end
