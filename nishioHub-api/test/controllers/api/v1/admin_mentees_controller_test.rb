require 'test_helper'
require 'csv'
class Api::V1::AdminMenteesControllerTest < ActionDispatch::IntegrationTest
  ROOT = '/api/v1/admin/mentees'
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'mentees-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'mentees-super@example.test')
    @mentee = create_mentee
    @mentor = create_mentor
    @program = PlatformProgram.create!(title: 'Software Development')
    @headers = auth_headers(@admin)
  end
  def body = response.parsed_body
  def row(user = @mentee)
    get "#{ROOT}/#{user.id}", headers: @headers
    assert_response :ok
    body['mentee']
  end
  def draft(**extra)
    { full_name: 'New Learner', email: 'new-mentee@example.test', phone_number: '+256700090001', password: 'MenteeInitial123', school: 'Nakasero School', grade: 'P6', mentor_id: @mentor.id, program_id: @program.id }.merge(extra)
  end
  def upload(rows)
    file = Tempfile.new(['mentee-import', '.csv'])
    file.write(CSV.generate { |csv| csv << AdminUserImport::HEADERS; rows.each { |r| csv << r } })
    file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'text/csv')]
  end
  test 'only authorized staff can read or modify mentees' do
    get ROOT
    assert_response :unauthorized
    [@mentee, @mentor].each do |actor|
      get ROOT, headers: auth_headers(actor)
      assert_response :forbidden
      post ROOT, headers: auth_headers(actor), params: { mentee: draft }, as: :json
      assert_response :forbidden
    end
    [@admin, @super].each do |actor|
      get ROOT, headers: auth_headers(actor)
      assert_response :ok
      assert_equal 1, body.dig('stats', 'total')
      assert_not_includes response.body, 'hashed_password'
      assert_equal 'no-store', response.headers['Cache-Control']
    end
    @admin.role.update!(permissions: ['users.read'])
    post ROOT, headers: @headers, params: { mentee: draft }, as: :json
    assert_response :forbidden
    patch "#{ROOT}/#{@mentee.id}/status", headers: @headers, params: { mentee: { status: 'suspended', lock_version: 0, profile_version: 0 } }, as: :json
    assert_response :forbidden
    get "#{ROOT}/export", headers: @headers
    assert_response :forbidden
    @admin.role.update!(permissions: [])
    get ROOT, headers: @headers
    assert_response :forbidden
  end
  test 'search sorting pagination and multiple roles stay scoped to mentees' do
    @mentor.additional_roles << @mentee.role
    get ROOT, headers: @headers, params: { q: @mentor.email }
    assert_response :ok
    assert_equal [@mentor.id], body['mentees'].map { |u| u['id'] }
    get ROOT, headers: @headers, params: { q: "NH-#{@mentee.id}" }
    assert_equal [@mentee.id], body['mentees'].map { |u| u['id'] }
    5.times { |i| create_mentee(email: "learner-#{i}@example.test") }
    get ROOT, headers: @headers, params: { per_page: 5, page: 2, sort: 'name', direction: 'asc' }
    assert_response :ok
    assert_equal 2, body['mentees'].size
    assert_equal 7, body.dig('meta', 'total')
    [{ status: 'unknown' }, { sort: 'hashed_password' }, { program_id: 'bad' }, { mentor_id: 'bad' }, { per_page: 1000 }].each do |params|
      get ROOT, headers: @headers, params: params
      assert_response :unprocessable_entity
    end
    get "#{ROOT}/#{@super.id}", headers: @headers
    assert_response :not_found
  end
  test 'creation forces mentee role and persists mentor and program assignments' do
    post ROOT, headers: @headers, params: { mentee: draft(role_ids: [@super.role_id], is_verified: true) }, as: :json
    assert_response :created
    user = User.find(body['id'])
    assert_equal 'mentee', user.role.canonical_name
    assert_not user.is_verified?
    assert user.authenticate('MenteeInitial123')
    assert_equal @mentor.id, user.mentee_profile.assigned_mentor_id
    assert_equal @program.id, user.mentee_profile.primary_program_id
    assert ProgramMembership.active.exists?(user: user, platform_program: @program)
    assert AdministrationAudit.exists?(action: 'mentee.created', target_id: user.id)
    assert_not_includes response.body, 'MenteeInitial123'

  end
  test 'assignment appears in both dashboards before a session exists' do
    @mentee.create_mentee_profile!(assigned_mentor: @mentor)
    get '/api/v1/me/mentorship', headers: auth_headers(@mentor)
    assert_response :ok
    assert_equal [@mentee.id], body['mentees'].map { |m| m['id'] }
    assert_equal 0, body['mentees'].first['progress']
    assert_equal 1, body.dig('stats', 'mentees')
    get '/api/v1/me/mentee_dashboard', headers: auth_headers(@mentee)
    assert_response :ok
    assert_equal @mentor.id, body.dig('mentor', 'id')
  end
  test 'edits preserve additional roles and reject stale profile or account revisions' do
    @mentee.additional_roles << @mentor.role
    item = row
    patch "#{ROOT}/#{@mentee.id}", headers: @headers, params: { mentee: { school: 'New School', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :ok
    assert @mentee.reload.has_role?('mentor')
    assert_equal 'New School', @mentee.mentee_profile.school
    patch "#{ROOT}/#{@mentee.id}", headers: @headers, params: { mentee: { school: 'Stale', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :conflict
    item = row
    @mentee.mentee_profile.update!(school: 'Self edited')
    patch "#{ROOT}/#{@mentee.id}", headers: @headers, params: { mentee: { school: 'Overwrite', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :conflict
    assert_equal 'Self edited', @mentee.mentee_profile.reload.school
  end
  test 'invalid assignments roll back account edits and memberships' do
    item = row
    patch "#{ROOT}/#{@mentee.id}", headers: @headers, params: { mentee: { full_name: 'Should roll back', mentor_id: @super.id, program_id: @program.id, lock_version: item['lock_version'], profile_version: 0 } }, as: :json
    assert_response :not_found
    assert_equal 'Mentee User', @mentee.reload.full_name
    assert_equal 0, ProgramMembership.count
    @program.update!(status: 'archived')
    post ROOT, headers: @headers, params: { mentee: draft }, as: :json
    assert_response :not_found
    assert_not User.exists?(email: 'new-mentee@example.test')
  end
  test 'changing primary program retains session and membership history and other memberships' do
    @mentee.create_mentee_profile!(primary_program: @program)
    @program.program_memberships.create!(user: @mentee)
    other = PlatformProgram.create!(title: 'Other membership')
    other.program_memberships.create!(user: @mentee)
    replacement = PlatformProgram.create!(title: 'New primary program')
    item = row
    patch "#{ROOT}/#{@mentee.id}", headers: @headers, params: { mentee: { program_id: replacement.id, lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :ok
    assert_equal replacement.id, @mentee.mentee_profile.reload.primary_program_id
    assert_not @program.program_memberships.find_by!(user: @mentee).is_active?
    assert other.program_memberships.find_by!(user: @mentee).is_active?
    assert replacement.program_memberships.active.exists?(user: @mentee)
    get ROOT, headers: @headers, params: { program_id: other.id }
    assert_equal [@mentee.id], body['mentees'].map { |m| m['id'] }
  end
  test 'status transitions distinguish graduation from suspension and revoke access' do
    token = auth_headers(@mentee)
    item = row
    patch "#{ROOT}/#{@mentee.id}/status", headers: @headers, params: { mentee: { status: 'suspended', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :ok
    assert_equal 'suspended', body['status']
    assert_not @mentee.reload.is_active?
    get '/api/v1/users/me', headers: token
    assert_response :unauthorized
    item = row
    patch "#{ROOT}/#{@mentee.id}/status", headers: @headers, params: { mentee: { status: 'graduated', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :ok
    assert @mentee.reload.is_active?
    assert_equal 'graduated', body['status']
    get ROOT, headers: @headers, params: { tab: 'graduated' }
    assert_equal [@mentee.id], body['mentees'].map { |m| m['id'] }
    assert_equal 1, body.dig('statuses', 'graduated')
  end
  test 'bulk status changes are atomic when any displayed revision is stale' do
    other = create_mentee(email: 'bulk-other@example.test')
    first = row
    second = row(other)
    versions = { @mentee.id => { lock_version: first['lock_version'], profile_version: first['profile_version'] }, other.id => { lock_version: -1, profile_version: second['profile_version'] } }
    post "#{ROOT}/bulk-status", headers: @headers, params: { user_ids: [@mentee.id, other.id], status: 'inactive', versions: versions }, as: :json
    assert_response :conflict
    assert @mentee.reload.is_active?
    assert other.reload.is_active?
    versions[other.id][:lock_version] = second['lock_version']
    post "#{ROOT}/bulk-status", headers: @headers, params: { user_ids: [@mentee.id, other.id], status: 'inactive', versions: versions }, as: :json
    assert_response :ok
    assert_equal 2, body['updated']
    assert_not @mentee.reload.is_active?
    assert_not other.reload.is_active?
  end
  test 'admins cannot edit mentees who also hold staff privileges' do
    @super.additional_roles << @mentee.role
    item = row(@super)
    patch "#{ROOT}/#{@super.id}", headers: @headers, params: { mentee: { school: 'Denied', lock_version: item['lock_version'], profile_version: 0 } }, as: :json
    assert_response :forbidden
  end
  test 'reports use real progress completed sessions reviews and exclusive program totals' do
    service = create_service(mentor: @mentor)
    booking = create_booking(service: service, mentor: @mentor, mentee: @mentee, status: 'completed')
    booking.create_review!(service: service, mentor: @mentor, mentee: @mentee, rating: 4, comment: 'Useful session')
    @mentee.mentee_goals.create!(title: 'First goal', progress: 100, completed: true)
    @mentee.mentee_goals.create!(title: 'Second goal', progress: 50)
    @mentee.update_columns(last_active_at: 1.day.ago)
    @program.program_memberships.create!(user: @mentee)
    other = PlatformProgram.create!(title: 'Additional program')
    other.program_memberships.create!(user: @mentee)
    get ROOT, headers: @headers
    assert_response :ok
    assert_equal 75, body['mentees'].first['progress']
    assert_equal 1, body['mentees'].first['completed_sessions']
    assert_equal 4.0, body.dig('stats', 'satisfaction')
    assert_equal 100.0, body.dig('stats', 'engagement_rate')
    assert_equal 1, body['distribution'].sum { |s| s['count'] }
    assert_equal 2, body['mentees'].first['programs'].size
    assert_equal 6, body['growth'].size
    assert_equal 1, body['engagement'].find { |e| e['key'] == 'goals' }['count']
    get ROOT, headers: @headers, params: { mentor_id: @mentor.id }
    assert_equal [@mentee.id], body['mentees'].map { |m| m['id'] }
  end
  test 'export scopes to mentees filters selected ids and escapes spreadsheet formulas' do
    @mentee.update!(full_name: '=SUM(1,2)')
    get "#{ROOT}/export", headers: @headers, params: { user_ids: [@mentee.id] }
    assert_response :ok
    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.size
    assert_equal "'=SUM(1,2)", rows.first['full_name']
    assert_not_includes response.body, @super.email
    assert_not_includes response.body, 'hashed_password'
  end
  test 'CSV preview and import only accept mentees and never return passwords' do
    file, csv = upload([['Imported learner', 'imported-mentee@example.test', '+256700090002', 'mentee', 'School', 'PrivateImport123']])
    post "#{ROOT}/import-preview", headers: @headers, params: { file: csv }
    assert_response :ok
    assert body['valid']
    assert_not_includes response.body, 'PrivateImport123'
    assert_not User.exists?(email: 'imported-mentee@example.test')
    post "#{ROOT}/import", headers: @headers, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
    assert_response :created
    assert_equal 1, body['imported']
    assert User.find_by!(email: 'imported-mentee@example.test').has_role?('mentee')
    file.close!
    file, csv = upload([['Not mentee', 'not-mentee@example.test', '+256700090003', 'mentor', 'School', 'PrivateImport123']])
    post "#{ROOT}/import-preview", headers: @headers, params: { file: csv }
    assert_response :ok
    assert_not body['valid']
    post "#{ROOT}/import", headers: @headers, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
    assert_response :unprocessable_entity
    assert_not User.exists?(email: 'not-mentee@example.test')
    file.close!
  end
  test 'search follows mentor program and session relationships and members cannot assign themselves' do
    @mentee.create_mentee_profile!(assigned_mentor: @mentor)
    @program.program_memberships.create!(user: @mentee)
    service = create_service(mentor: @mentor, title: 'Distinctive session title')
    create_booking(service: service, mentor: @mentor, mentee: @mentee)
    [@program.title, @mentor.full_name, service.title].each do |query|
      get ROOT, headers: @headers, params: { q: query }
      assert_response :ok
      assert_equal [@mentee.id], body['mentees'].map { |m| m['id'] }
    end
    patch '/api/v1/me/mentee_profile', headers: auth_headers(@mentee), params: { profile: { school: 'Own School', assigned_mentor_id: @super.id, management_status: 'graduated' } }, as: :json
    assert_response :ok
    assert_equal @mentor.id, @mentee.mentee_profile.reload.assigned_mentor_id
    assert_equal 'active', @mentee.mentee_profile.management_status
  end

  test 'searchable options distinguish filter choices from eligible assignments' do
    @mentor.update!(is_active: false)
    get "#{ROOT}/options", headers: @headers, params: { q: @mentor.full_name }
    assert_response :ok
    assert_equal [@mentor.id], body['mentors'].map { |m| m['id'] }
    get "#{ROOT}/options", headers: @headers, params: { q: @mentor.full_name, active_only: 'true' }
    assert_response :ok
    assert_empty body['mentors']
    @program.update!(status: 'archived')
    get "#{ROOT}/options", headers: @headers, params: { q: @program.title, active_only: 'true' }
    assert_response :ok
    assert_empty body['programs']
  end

end
