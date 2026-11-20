require 'test_helper'
require 'csv'
require 'zlib'
require 'stringio'
require 'rubygems/package'
class Api::V1::AdminSessionDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'details-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'details-super@example.test')
    @mentor = create_mentor
    @mentee = create_mentee
    @other = create_mentee(email: 'session-details-second@example.test')
    @service = create_service(mentor: @mentor)
    @booking = create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'completed', scheduled_at: 2.hours.ago)
    @booking.booking_participants.create!(user: @other)
    @root = "/api/v1/admin/sessions/#{@booking.id}"
    @headers = auth_headers(@admin)
  end
  def body = response.parsed_body
  def asset(**attrs) = @booking.session_assets.create!({ kind: 'material', title: 'Learning Guide', url: 'https://example.com/guide' }.merge(attrs))
  def metadata(**attrs) = { updated_at: @booking.reload.updated_at.iso8601(6) }.merge(attrs)
  def upload_pdf
    file = Tempfile.new(['session-material', '.pdf']); file.binmode; file.write("%PDF-1.4\n%Learning Guide\n%%EOF\n"); file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'application/pdf')]
  end
  test 'details use real attendance feedback and strict administration permissions' do
    @booking.booking_participants.first.update!(attended: true)
    @booking.create_review!(service: @service, mentor: @mentor, mentee: @mentee, rating: 4, comment: 'Original feedback')
    @booking.session_feedbacks.create!(user: @mentee, rating: 5, comment: 'Updated feedback')
    @booking.session_feedbacks.create!(user: @other, rating: 3, comment: 'Another perspective')
    get "#{@root}/details"
    assert_response :unauthorized
    [@mentee, @mentor].each { |u| get "#{@root}/details", headers: auth_headers(u); assert_response :forbidden }
    [@admin, @super].each do |u|
      get "#{@root}/details", headers: auth_headers(u)
      assert_response :ok
      assert_equal 2, body['attendees']
      assert_equal 1, body['attended']
      assert_equal 2, body.dig('summary', 'feedback_count')
      assert_equal 4.0, body.dig('summary', 'rating')
      assert_equal 0, body.dig('summary', 'recording_views')
      assert body.dig('capabilities', 'manage')
      assert_equal 'private, no-store', response.headers['Cache-Control']
    end
    @admin.role.update!(permissions: ['dashboard.read'])
    get "#{@root}/details", headers: @headers
    assert_response :ok
    assert_not body.dig('capabilities', 'manage')
    patch "#{@root}/details", headers: @headers, params: { details: metadata(objectives: ['Learn']) }, as: :json
    assert_response :forbidden
  end
  test 'completed session overview is editable without changing schedule billing or shared offerings' do
    version = @booking.updated_at.iso8601(6)
    patch "#{@root}/details", headers: @headers, params: { details: metadata(session_title: 'Updated session', session_description: 'Practical examples', objectives: ['Learn tools', 'Build a project'], tags: ['Python', 'Beginner'], registration_opens_at: 1.week.ago.iso8601, registration_closes_at: 1.day.ago.iso8601, feedback_opens_at: 30.minutes.ago.iso8601, feedback_closes_at: 3.days.from_now.iso8601) }, as: :json
    assert_response :ok
    assert_equal 'Updated session', @booking.reload.session_title
    assert_equal ['Learn tools', 'Build a project'], body['objectives']
    assert_equal ['Python', 'Beginner'], body['tags']
    assert_equal 'completed', @booking.status
    assert_equal @service.price, @booking.total_price
    assert_equal 'Mentoring Session', @service.reload.title
    patch "#{@root}/details", headers: @headers, params: { details: { updated_at: version, tags: ['Stale'] } }, as: :json
    assert_response :conflict
    [{ objectives: 'wrong' }, { objectives: Array.new(21, 'Goal') }, { tags: ['x' * 41] }, { session_title: '' }, { feedback_opens_at: 1.day.ago.iso8601 }, { registration_closes_at: 1.day.from_now.iso8601 }, { registration_opens_at: 'invalid' }].each do |values|
      patch "#{@root}/details", headers: @headers, params: { details: metadata(**values) }, as: :json
      assert_response :unprocessable_entity
    end
    patch "#{@root}/details", headers: @headers, params: { details: metadata(clear_objectives: 'true', clear_tags: 'true') }, as: :json
    assert_response :ok
    assert_empty body['objectives']
    assert_empty body['tags']
  end
  test 'content files are scoped authenticated and learner access drives engagement while staff previews do not' do
    file, uploaded = upload_pdf
    post "#{@root}/assets", headers: @headers, params: { asset: { kind: 'material', title: 'PDF Guide', file: uploaded } }
    assert_response :created
    item = SessionAsset.find(body['id'])
    get "#{@root}/assets/#{item.id}/file", headers: @headers
    assert_response :ok
    assert_equal 0, SessionAssetAccess.count
    get "/api/v1/bookings/#{@booking.id}/session-assets/#{item.id}/file", headers: auth_headers(@other)
    assert_response :ok
    assert_includes response.body, '%PDF'
    assert_equal 1, SessionAssetAccess.where(kind: 'download').count
    recording = asset(kind: 'recording', title: 'Recording', url: 'https://example.com/video')
    post "/api/v1/bookings/#{@booking.id}/session-assets/#{recording.id}/access", headers: auth_headers(@other)
    assert_response :ok
    assert_equal 1, SessionAssetAccess.where(kind: 'view').count
    outsider = create_mentee(email: 'outsider-session@example.test')
    get "/api/v1/bookings/#{@booking.id}/session-assets/#{item.id}/file", headers: auth_headers(outsider)
    assert_response :not_found
    get "#{@root}/details", headers: @headers
    assert_equal 1, body.dig('summary', 'recording_views')
    assert_equal 1, body.dig('summary', 'material_downloads')
    delete "#{@root}/assets/#{recording.id}", headers: @headers, params: { lock_version: 999 }, as: :json
    assert_response :conflict
    delete "#{@root}/assets/#{recording.id}", headers: @headers, params: { lock_version: recording.lock_version }, as: :json
    assert_response :no_content
    assert_not recording.reload.is_active
    assert_equal 2, SessionAssetAccess.count
    post "/api/v1/bookings/#{@booking.id}/session-assets/#{recording.id}/access", headers: auth_headers(@other)
    assert_response :not_found
    file.close!
  end
  test 'unsupported content and unsafe links are rejected and material archives contain real files and links' do
    post "#{@root}/assets", headers: @headers, params: { asset: { kind: 'material', title: 'Unsafe', url: 'javascript:alert(1)' } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, SessionAsset.count
    file, uploaded = upload_pdf
    item = @booking.session_assets.new(kind: 'material', title: 'Guide'); item.file.attach(uploaded); item.save!
    asset
    get "#{@root}/materials-archive", headers: @headers
    assert_response :ok
    tar = Zlib::GzipReader.new(StringIO.new(response.body))
    names = Gem::Package::TarReader.new(tar).map { |entry| entry.full_name }
    assert names.any? { |v| v.end_with?('.pdf') }
    assert_includes names, 'material-links.txt'
    assert_equal 0, SessionAssetAccess.count
    file.close!
  end
  test 'notes and audit are administrator only scoped and revision protected' do
    post "#{@root}/notes", headers: @headers, params: { note: { body: 'Prepare the next workshop' } }, as: :json
    assert_response :no_content
    note = @booking.session_notes.first
    patch "#{@root}/notes/#{note.id}", headers: @headers, params: { note: { body: 'Updated note', lock_version: note.lock_version } }, as: :json
    assert_response :no_content
    patch "#{@root}/notes/#{note.id}", headers: @headers, params: { note: { body: 'Stale', lock_version: 0 } }, as: :json
    assert_response :conflict
    get "#{@root}/sections/notes", headers: @headers
    assert_response :ok
    assert_equal 'Updated note', body['items'].first['body']
    get "#{@root}/sections/audit", headers: @headers
    assert_response :ok
    assert_equal 2, body['items'].count { |r| r['action'] == 'session.note_saved' }
    get "/api/v1/bookings/#{@booking.id}/session-content", headers: auth_headers(@mentee)
    assert_response :ok
    assert_not_includes response.body, 'Updated note'
    delete "#{@root}/notes/#{note.id}", headers: @headers, params: { lock_version: note.reload.lock_version }, as: :json
    assert_response :no_content
    assert_equal 0, @booking.session_notes.count
  end
  test 'follow ups respect preferences and retry keys do not duplicate notifications' do
    @other.create_notification_preference!(mentorship: false)
    baseline = Notification.count
    values = { message: 'Thank you for attending. Please review the materials.', request_key: SecureRandom.uuid }
    2.times do
      post "#{@root}/follow-up", headers: @headers, params: { follow_up: values }, as: :json
      assert_response :ok
      assert_equal 1, body['delivered']
      assert_equal 1, body['skipped']
    end
    assert_equal baseline + 1, Notification.count
    @admin.role.update!(permissions: ['dashboard.read'])
    post "#{@root}/follow-up", headers: @headers, params: { follow_up: values.merge(request_key: SecureRandom.uuid) }, as: :json
    assert_response :forbidden
  end
  test 'duplication copies overview materials and roster but starts with fresh attendance feedback and recordings' do
    asset
    asset(kind: 'recording', title: 'Old Recording', url: 'https://example.com/video')
    @booking.update!(objectives: ['Build skills'], session_tags: ['Python'])
    @booking.booking_participants.first.update!(attended: true)
    @booking.session_feedbacks.create!(user: @mentee, rating: 5, comment: 'Great')
    post "#{@root}/duplicate", headers: @headers, params: { session: { title: 'Next workshop', description: 'Repeat workshop', mentor_id: @mentor.id, mentee_ids: [@mentee.id, @other.id], category_id: @service.category_id, scheduled_at: 2.days.from_now.iso8601, duration: 60, format: 'online' } }, as: :json
    assert_response :created
    copy = Booking.find(body['id'])
    assert_not_equal @booking.id, copy.id
    assert_equal ['Build skills'], copy.objectives
    assert_equal 1, copy.session_assets.active.where(kind: 'material').count
    assert_equal 0, copy.session_assets.where(kind: 'recording').count
    assert_equal 2, copy.booking_participants.count
    assert_equal 0, copy.booking_participants.where(attended: true).count
    assert_equal 0, copy.session_feedbacks.count
    assert_equal 'completed', @booking.reload.status
  end
  test 'feedback is available to registered learners only and summary deduplicates legacy review' do
    @booking.create_review!(service: @service, mentor: @mentor, mentee: @mentee, rating: 3, comment: 'Old review')
    put "/api/v1/bookings/#{@booking.id}/session-feedback", headers: auth_headers(@mentee), params: { feedback: { rating: 5, comment: 'Very practical' } }, as: :json
    assert_response :ok
    get "#{@root}/details", headers: @headers
    assert_equal 1, body.dig('summary', 'feedback_count')
    assert_equal 5.0, body.dig('summary', 'rating')
    put "/api/v1/bookings/#{@booking.id}/session-feedback", headers: auth_headers(@other), params: { feedback: { rating: 4.5, comment: 'Invalid score' } }, as: :json
    assert_response :unprocessable_entity
    @booking.update!(feedback_closes_at: 1.minute.ago)
    put "/api/v1/bookings/#{@booking.id}/session-feedback", headers: auth_headers(@other), params: { feedback: { rating: 4, comment: 'Late response' } }, as: :json
    assert_response :forbidden
  end
  test 'attendee export neutralizes formulas and sections reject arbitrary names' do
    @mentee.update!(full_name: '=Formula Name')
    get "#{@root}/attendees-export", headers: @headers
    assert_response :ok
    rows = CSV.parse(response.body, headers: true)
    assert_equal 2, rows.size
    assert_equal "'=Formula Name", rows.first['name']
    assert_not_includes response.body, @mentee.email
    get "#{@root}/sections/arbitrary", headers: @headers
    assert_response :unprocessable_entity
    get "#{@root}/participants", headers: @headers, params: { q: '=Formula' }
    assert_response :ok
    assert_equal 1, body['items'].size
  end
  test 'cover uploads are validated and can be removed without changing attendance' do
    file = Tempfile.new(['session-cover', '.png']); file.binmode
    file.write(Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jPp8AAAAASUVORK5CYII=')); file.flush
    patch "#{@root}/details", headers: @headers, params: { details: metadata(cover: Rack::Test::UploadedFile.new(file.path, 'image/png')) }
    assert_response :ok
    assert @booking.reload.cover.attached?
    assert body['cover'].start_with?('http')
    assert_equal 2, @booking.booking_participants.count
    patch "#{@root}/details", headers: @headers, params: { details: metadata(remove_cover: true) }, as: :json
    assert_response :ok
    assert_not @booking.reload.cover.attached?
    file.close!
  end

end
