require 'test_helper'
require 'csv'
class Api::V1::AdminProgramsControllerTest < ActionDispatch::IntegrationTest
  ROOT = '/api/v1/admin/programs'
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'program-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'program-super@example.test')
    @mentor = create_mentor
    @mentee = create_mentee
    @category = Category.create!(name: 'Data & AI', slug: 'data-ai')
    @program = PlatformProgram.create!(title: 'Data Science', category: @category, starts_on: Date.current - 2, ends_on: Date.current + 90)
    @headers = auth_headers(@admin)
  end
  def body = response.parsed_body
  def draft(**changes) = { title: 'New Program', description: 'Learn useful skills', icon: 'code', category_id: @category.id, status: 'draft', starts_on: '2026-11-01', ends_on: '2027-01-01', mentor_ids: [@mentor.id] }.merge(changes)
  def csv_file(rows)
    file = Tempfile.new(['program-import', '.csv'])
    file.write(CSV.generate { |csv| csv << AdminProgramImport::HEADERS; rows.each { |row| csv << row } })
    file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'text/csv')]
  end
  test 'program access and mutation permissions are enforced' do
    get ROOT
    assert_response :unauthorized
    [@mentee, @mentor].each { |user| get ROOT, headers: auth_headers(user); assert_response :forbidden }
    [@admin, @super].each do |user|
      get ROOT, headers: auth_headers(user)
      assert_response :ok
      assert_equal 1, body.dig('stats', 'total')
      assert_equal 'private, no-store', response.headers['Cache-Control']
      assert_not_includes response.body, 'hashed_password'
    end
    @admin.role.update!(permissions: ['dashboard.read'])
    post ROOT, headers: @headers, params: { program: draft }, as: :json
    assert_response :forbidden
    get ROOT, headers: @headers
    assert_response :ok
    assert_not body.dig('capabilities', 'manage')
    @admin.role.update!(permissions: [])
    get ROOT, headers: @headers
    assert_response :forbidden
  end
  test 'counts progress mentors rating and rankings are derived from program data' do
    member = @program.program_memberships.create!(user: @mentee, progress: 75)
    @program.program_mentor_assignments.create!(user: @mentor)
    @program.program_memberships.create!(user: @mentor)
    @mentee.update_columns(last_active_at: 1.day.ago)
    service = create_service(mentor: @mentor)
    booking = create_booking(service: service, mentor: @mentor, mentee: @mentee, status: 'completed')
    booking.update!(platform_program: @program)
    booking.create_review!(service: service, mentor: @mentor, mentee: @mentee, rating: 4, comment: 'Useful program session')
    get ROOT, headers: @headers
    assert_response :ok
    assert_equal 1, body.dig('stats', 'enrollments')
    assert_equal 1, body.dig('stats', 'active_participants')
    assert_equal 4.0, body.dig('stats', 'rating')
    assert_equal 75, body['programs'].first['progress']
    assert_equal 1, body['programs'].first['enrolled']
    assert_equal [@mentor.id], body['programs'].first['mentors'].map { |m| m['id'] }
    assert_equal 'ongoing', body['programs'].first['display_status']
    assert_equal @program.id, body['top_programs'].first['id']
    assert_equal 6, body['trend'].size
    assert_equal 1, body['distribution'].sum { |d| d['count'] }
    assert_nil member.completed_at
  end
  test 'filters search sorting pagination and bad options are validated' do
    @program.program_mentor_assignments.create!(user: @mentor)
    5.times { |i| PlatformProgram.create!(title: "Program #{i}", status: 'draft') }
    get ROOT, headers: @headers, params: { tab: 'active', category_id: @category.id, mentor_id: @mentor.id, q: @mentor.full_name }
    assert_response :ok
    assert_equal [@program.id], body['programs'].map { |p| p['id'] }
    get ROOT, headers: @headers, params: { page: 2, per_page: 5 }
    assert_equal 1, body['programs'].size
    [{ status: 'bad' }, { sort: 'password' }, { direction: 'bad' }, { months: '100' }, { per_page: 100 }, { mentor_id: 'bad' }].each do |params|
      get ROOT, headers: @headers, params: params
      assert_response :unprocessable_entity
    end
  end
  test 'creates and edits categorized programs with mentor assignment and revisions' do
    post ROOT, headers: @headers, params: { program: draft(created_by_id: @mentee.id) }, as: :json
    assert_response :created
    program = PlatformProgram.find(body['id'])
    assert_equal @admin.id, program.created_by_id
    assert program.program_mentor_assignments.active.exists?(user: @mentor)
    item = body
    patch "#{ROOT}/#{program.id}", headers: @headers, params: { program: { title: 'Edited program', mentor_ids: [], lock_version: item['lock_version'] } }, as: :json
    assert_response :ok
    assert_equal 0, program.program_mentor_assignments.active.count
    patch "#{ROOT}/#{program.id}", headers: @headers, params: { program: { title: 'Stale', lock_version: item['lock_version'] } }, as: :json
    assert_response :conflict
    post ROOT, headers: @headers, params: { program: draft(title: 'Invalid', mentor_ids: [@mentee.id]) }, as: :json
    assert_response :unprocessable_entity
    assert_not PlatformProgram.exists?(title: 'Invalid')
    post ROOT, headers: @headers, params: { program: draft(title: 'Bad date', starts_on: 'garbage') }, as: :json
    assert_response :unprocessable_entity
    post ROOT, headers: @headers, params: { program: draft(title: 'Backwards', starts_on: '2027-05-01') }, as: :json
    assert_response :unprocessable_entity
  end
  test 'enrollment management preserves progress history and blocks stale and cross program edits' do
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :no_content
    member = @program.program_memberships.find_by!(user: @mentee)
    patch "#{ROOT}/#{@program.id}/members/#{member.id}", headers: @headers, params: { enrollment: { progress: 100, lock_version: member.lock_version } }, as: :json
    assert_response :no_content
    assert member.reload.completed_at.present?
    patch "#{ROOT}/#{@program.id}/members/#{member.id}", headers: @headers, params: { enrollment: { progress: 10, lock_version: 0 } }, as: :json
    assert_response :conflict
    delete "#{ROOT}/#{@program.id}/members/#{member.id}", headers: @headers, params: { lock_version: member.lock_version }, as: :json
    assert_response :no_content
    assert_not member.reload.is_active?
    assert_equal 100, member.progress
    get "#{ROOT}/#{@program.id}/members", headers: @headers, params: { status: 'withdrawn' }
    assert_equal 1, body.dig('meta', 'total')
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :no_content
    assert_equal 1, @program.program_memberships.count
    assert_equal 100, member.reload.progress
    other = PlatformProgram.create!(title: 'Other')
    patch "#{ROOT}/#{other.id}/members/#{member.id}", headers: @headers, params: { enrollment: { progress: 5, lock_version: member.lock_version } }, as: :json
    assert_response :not_found
    @program.update!(status: 'archived')
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :unprocessable_entity
  end
  test 'bulk changes are atomic on stale versions and archiving retains memberships' do
    other = PlatformProgram.create!(title: 'Other')
    @program.program_memberships.create!(user: @mentee)
    post "#{ROOT}/bulk-status", headers: @headers, params: { program_ids: [@program.id, other.id], status: 'archived', versions: { @program.id => @program.lock_version, other.id => -1 } }, as: :json
    assert_response :conflict
    assert_equal 'active', @program.reload.status
    post "#{ROOT}/bulk-status", headers: @headers, params: { program_ids: [@program.id, other.id], status: 'archived', versions: { @program.id => @program.lock_version, other.id => other.lock_version } }, as: :json
    assert_response :ok
    assert_equal 1, @program.program_memberships.active.count
  end
  test 'CSV export respects filters escapes formulas and includes no account credentials' do
    @program.update!(title: '=SUM(1,2)')
    get "#{ROOT}/export", headers: @headers, params: { program_ids: [@program.id] }
    assert_response :ok
    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.size
    assert_equal "'=SUM(1,2)", rows.first['title']
    assert_not_includes response.body, @admin.email
  end
  test 'CSV preview is read only import is atomic and repeat imports reject duplicates' do
    file, csv = csv_file([['CSV program', 'Description', @category.name, 'draft', '2026-11-01', '2027-01-01', 'code']])
    post "#{ROOT}/import-preview", headers: @headers, params: { file: csv }
    assert_response :ok
    assert body['valid']
    assert_not PlatformProgram.exists?(title: 'CSV program')
    post "#{ROOT}/import", headers: @headers, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
    assert_response :created
    assert_equal 1, body['imported']
    post "#{ROOT}/import", headers: @headers, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
    assert_response :unprocessable_entity
    file.close!
    file, csv = csv_file([['Valid row', '', '', 'draft', '', '', ''], ['Invalid row', '', 'Missing category', 'bad', '', '', '']])
    post "#{ROOT}/import", headers: @headers, params: { file: csv }
    assert_response :unprocessable_entity
    assert_not PlatformProgram.exists?(title: 'Valid row')
    file.close!
  end
  test 'removing a dual role program mentor does not withdraw the same learners enrollment' do
    @mentee.additional_roles << @mentor.role
    @program.program_memberships.create!(user: @mentee, progress: 60)
    @program.program_mentor_assignments.create!(user: @mentee)
    patch "#{ROOT}/#{@program.id}", headers: @headers, params: { program: { mentor_ids: [], lock_version: @program.lock_version } }, as: :json
    assert_response :ok
    assert_equal 1, @program.program_memberships.active.count
    assert_equal 60, @program.program_memberships.first.progress
    assert_empty @program.program_mentor_assignments.active
  end
  test 'member pagination and linked records are scoped and have no private account fields' do
    21.times do |i|
      person = create_mentee(email: "program-member-#{i}@example.test")
      @program.program_memberships.create!(user: person)
    end
    get "#{ROOT}/#{@program.id}/members", headers: @headers, params: { page: 2 }
    assert_response :ok
    assert_equal 1, body['items'].size
    assert_equal 21, body.dig('meta', 'total')
    assert_not_includes response.body, 'hashed_password'
    assert_includes response.body, '@example.test'
    @admin.role.update!(permissions: ['dashboard.read'])
    get "#{ROOT}/#{@program.id}/members", headers: @headers
    assert_response :ok
    assert_nil body['items'].first['email']
    assert_not_includes response.body, '@example.test'
    resource = PlatformResource.create!(title: 'Scoped resource', url: 'https://example.com', platform_program: @program)
    PlatformResource.create!(title: 'Unrelated resource', url: 'https://example.com')
    get "#{ROOT}/#{@program.id}/records/resources", headers: @headers
    assert_response :ok
    assert_equal [resource.id], body['items'].map { |r| r['id'] }
  end
  test 'trend periods include withdrawals without inflating rejoined enrollment counts' do
    member = @program.program_memberships.create!(user: @mentee, is_active: false)
    get ROOT, headers: @headers, params: { months: '12' }
    assert_response :ok
    assert_equal 1, body.dig('stats', 'enrollments')
    assert_equal 0, body['programs'].first['enrolled']
    assert_equal 12, body['trend'].size
    assert_nil body.dig('stats', 'rating')
    assert_nil body.dig('stats', 'enrollment_change')
    member.update!(is_active: true)
    get ROOT, headers: @headers, params: { months: '3' }
    assert_response :ok
    assert_equal 1, body.dig('stats', 'enrollments')
    assert_equal 1, body['programs'].first['enrolled']
  end

  test 'detail fields persist with accurate enrollment progress and permissions' do
    @program.program_memberships.create!(user: @mentee, progress: 100)
    second = create_mentee(email: 'second-detail@example.test')
    @program.program_memberships.create!(user: second, progress: 20)
    @program.program_memberships.create!(user: @mentor, progress: 90)
    withdrawn = create_mentee(email: 'withdrawn-detail@example.test')
    @program.program_memberships.create!(user: withdrawn, progress: 100, is_active: false)
    patch "#{ROOT}/#{@program.id}", headers: @headers, params: { program: {
      lock_version: @program.lock_version, capacity: 10, objectives: ['Learn analysis', 'Build a project'],
      target_audience: 'Students', delivery_mode: 'online', registration_starts_on: '2026-10-01',
      registration_ends_on: '2026-10-15', evaluation_starts_on: (@program.ends_on + 1).iso8601,
      evaluation_ends_on: (@program.ends_on + 10).iso8601
    } }, as: :json
    assert_response :ok
    [@admin, @super].each do |actor|
      get "#{ROOT}/#{@program.id}", headers: auth_headers(actor)
      assert_response :ok
      assert_equal 10, body['capacity']
      assert_equal ['Learn analysis', 'Build a project'], body['objectives']
      assert_equal 'Students', body['target_audience']
      assert_equal 'online', body['delivery_mode']
      assert_equal 60, body['progress']
      assert_equal({ 'completed' => 1, 'in_progress' => 1, 'not_started' => 0 }, body['progress_counts'])
      assert body.dig('capabilities', 'manage')
    end
    @admin.role.update!(permissions: ['dashboard.read'])
    get "#{ROOT}/#{@program.id}", headers: @headers
    assert_response :ok
    assert_not body.dig('capabilities', 'manage')
    assert_not body.dig('capabilities', 'view_users')
    patch "#{ROOT}/#{@program.id}", headers: @headers, params: { program: { capacity: 1, lock_version: @program.reload.lock_version } }, as: :json
    assert_response :forbidden
    [@mentor, @mentee].each do |actor|
      get "#{ROOT}/#{@program.id}", headers: auth_headers(actor)
      assert_response :forbidden
    end
  end
  test 'invalid detail fields and stale revisions do not change the program' do
    invalid = [{ capacity: 0 }, { objectives: 'wrong' }, { objectives: ['x' * 301] }, { objectives: Array.new(21, 'Objective') },
      { delivery_mode: 'unknown' }, { target_audience: 'x' * 501 }, { registration_starts_on: '2026-02-30' },
      { registration_starts_on: '2026-10-10', registration_ends_on: '2026-10-01' },
      { registration_ends_on: (@program.starts_on + 1).iso8601 }, { evaluation_starts_on: (@program.ends_on - 1).iso8601 }]
    invalid.each do |fields|
      patch "#{ROOT}/#{@program.id}", headers: @headers, params: { program: fields.merge(lock_version: @program.reload.lock_version) }, as: :json
      assert_response :unprocessable_entity
    end
    assert_nil @program.reload.capacity
    assert_empty @program.objectives
    patch "#{ROOT}/#{@program.id}", headers: @headers, params: { program: { capacity: 5, lock_version: 9999 } }, as: :json
    assert_response :conflict
  end
  test 'capacity prevents atomic over enrollment and supports rejoining without extra slots' do
    @program.update!(capacity: 1)
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :no_content
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :no_content
    other = create_mentee(email: 'capacity-other@example.test')
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [other.id] }, as: :json
    assert_response :unprocessable_entity
    assert_equal 1, @program.program_memberships.active.count
    member = @program.program_memberships.find_by!(user: @mentee)
    delete "#{ROOT}/#{@program.id}/members/#{member.id}", headers: @headers, params: { lock_version: member.lock_version }, as: :json
    assert_response :no_content
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [other.id] }, as: :json
    assert_response :no_content
    @program.update!(capacity: 2)
    post "#{ROOT}/#{@program.id}/members", headers: @headers, params: { user_ids: [@mentee.id] }, as: :json
    assert_response :no_content
    patch "#{ROOT}/#{@program.id}", headers: @headers, params: { program: { capacity: 1, lock_version: @program.reload.lock_version } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 2, @program.reload.capacity
  end

end
