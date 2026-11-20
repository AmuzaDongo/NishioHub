require 'test_helper'
require 'csv'

class Api::V1::AdminUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'users-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'users-super@example.test')
    @mentee = create_user(role: create_role('mentee'), email: 'users-mentee@example.test')
    @mentor_role = create_role('mentor')
  end

  def payload(**changes)
    { full_name: 'New Learner', email: 'new-admin-user@example.test', phone_number: '+256700002001',
      affiliation: 'Career Development', role_ids: [@mentee.role_id], primary_role_id: @mentee.role_id,
      password: 'InitialPass123', is_active: true, is_verified: false }.merge(changes)
  end

  def csv_file(rows)
    file = Tempfile.new(['users-import', '.csv'])
    file.write(CSV.generate { |csv| csv << AdminUserImport::HEADERS; rows.each { |row| csv << row } })
    file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'text/csv')]
  end

  test 'list details roles and management operations require administrator access' do
    get '/api/v1/admin/users'
    assert_response :unauthorized
    [@mentee, create_user(role: @mentor_role, email: 'only-mentor@example.test')].each do |user|
      get '/api/v1/admin/users', headers: auth_headers(user)
      assert_response :forbidden
      get '/api/v1/admin/roles', headers: auth_headers(user)
      assert_response :forbidden
      post '/api/v1/admin/users', headers: auth_headers(user), params: { user: payload }, as: :json
      assert_response :forbidden
      get '/api/v1/admin/users/export', headers: auth_headers(user)
      assert_response :forbidden
    end
    [@admin, @super].each do |user|
      get '/api/v1/admin/users', headers: auth_headers(user)
      assert_response :ok
      assert_equal User.count, response.parsed_body.dig('stats', 'total')
      assert_not_includes response.body, 'hashed_password'
      assert_not_includes response.body, 'refresh_token'
    end
  end

  test 'search filters sorting pagination and nonoverlapping distribution use persisted users' do
    @mentee.update!(affiliation: 'Nakasero School')
    @mentee.additional_roles << @mentor_role
    get '/api/v1/admin/users', headers: auth_headers(@admin), params: { q: 'Nakasero', role: 'mentor', status: 'active', sort: 'name', direction: 'asc', per_page: 10 }
    assert_response :ok
    assert_equal [@mentee.id], response.parsed_body['users'].map { |user| user['id'] }
    assert_equal 2, response.parsed_body['users'].first['roles'].size
    assert_equal User.count, response.parsed_body['distribution'].sum { |segment| segment['count'] }
    get '/api/v1/admin/users', headers: auth_headers(@admin), params: { q: @mentee.id.to_s }
    assert_includes response.parsed_body['users'].map { |user| user['id'] }, @mentee.id
    get '/api/v1/admin/users', headers: auth_headers(@admin), params: { sort: 'hashed_password' }
    assert_response :unprocessable_entity
  end

  test 'admins create member accounts but cannot grant any administrator role' do
    post '/api/v1/admin/users', headers: auth_headers(@admin), params: { user: payload }, as: :json
    assert_response :created
    user = User.find(response.parsed_body['id'])
    assert user.authenticate('InitialPass123')
    assert_equal 'Career Development', user.affiliation
    assert_not_includes response.body, 'InitialPass123'
    assert AdministrationAudit.exists?(target_id: user.id, action: 'user.created')
    post '/api/v1/admin/users', headers: auth_headers(@admin), params: { user: payload(email: 'escalated@example.test', phone_number: '+256700002002', role_ids: [@admin.role_id], primary_role_id: @admin.role_id) }, as: :json
    assert_response :forbidden
    assert_not User.exists?(email: 'escalated@example.test')
  end

  test 'super admins assign multiple roles and preserve an explicit primary role' do
    post '/api/v1/admin/users', headers: auth_headers(@super), params: { user: payload(role_ids: [@admin.role_id, @mentor_role.id], primary_role_id: @mentor_role.id) }, as: :json
    assert_response :created
    user = User.find(response.parsed_body['id'])
    assert_equal @mentor_role.id, user.role_id
    assert user.platform_admin?
    assert user.has_role?('mentor')
    get '/api/v1/admin/users', headers: auth_headers(user)
    assert_response :ok
    assert_includes User.with_role('mentor'), user
  end

  test 'staff accounts and the current account cannot be changed by an admin' do
    [@admin, @super].each do |target|
      patch "/api/v1/admin/users/#{target.id}", headers: auth_headers(@admin), params: { user: { full_name: 'Spoof', lock_version: target.reload.lock_version } }, as: :json
      assert_response :forbidden
      patch "/api/v1/admin/users/#{target.id}/status", headers: auth_headers(@admin), params: { account: { is_active: false }, lock_version: target.lock_version }, as: :json
      assert_response :forbidden
      assert target.reload.is_active?
    end
    patch "/api/v1/admin/users/#{@super.id}/status", headers: auth_headers(@super), params: { account: { is_active: false }, lock_version: @super.reload.lock_version }, as: :json
    assert_response :forbidden
  end

  test 'role and email changes invalidate sessions reject stale edits and preserve password privacy' do
    old_headers = auth_headers(@mentee)
    refresh = RefreshToken.issue_for(@mentee)
    version = @mentee.lock_version
    patch "/api/v1/admin/users/#{@mentee.id}", headers: auth_headers(@admin), params: { user: { role_ids: [@mentor_role.id, @mentee.role_id], primary_role_id: @mentor_role.id, lock_version: version } }, as: :json
    assert_response :ok
    assert @mentee.reload.has_role?('mentee')
    assert_equal @mentor_role.id, @mentee.role_id
    assert refresh.reload.revoked
    get '/api/v1/users/me', headers: old_headers
    assert_response :unauthorized
    patch "/api/v1/admin/users/#{@mentee.id}", headers: auth_headers(@admin), params: { user: { full_name: 'Stale', lock_version: version } }, as: :json
    assert_response :conflict
    assert_not_equal 'Stale', @mentee.reload.full_name
    get "/api/v1/admin/users/#{@mentee.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert response.parsed_body['history'].any?
    assert_not_includes response.body, 'hashed_password'
  end

  test 'deactivation reactivation password reset and session revocation are persisted' do
    headers = auth_headers(@mentee)
    refresh = RefreshToken.issue_for(@mentee)
    patch "/api/v1/admin/users/#{@mentee.id}/status", headers: auth_headers(@admin), params: { account: { is_active: false }, lock_version: @mentee.reload.lock_version }, as: :json
    assert_response :ok
    assert_not @mentee.reload.is_active?
    assert refresh.reload.revoked
    get '/api/v1/users/me', headers: headers
    assert_response :unauthorized
    patch "/api/v1/admin/users/#{@mentee.id}/status", headers: auth_headers(@admin), params: { account: { is_active: true }, lock_version: @mentee.lock_version }, as: :json
    assert_response :ok
    post "/api/v1/admin/users/#{@mentee.id}/password", headers: auth_headers(@admin), params: { password_change: { password: 'Replacement123', password_confirmation: 'Replacement123' }, lock_version: @mentee.reload.lock_version }, as: :json
    assert_response :ok
    assert @mentee.reload.authenticate('Replacement123')
    headers = auth_headers(@mentee)
    post "/api/v1/admin/users/#{@mentee.id}/revoke-sessions", headers: auth_headers(@admin), params: { lock_version: @mentee.lock_version }, as: :json
    assert_response :ok
    get '/api/v1/users/me', headers: headers
    assert_response :unauthorized
    assert_not AdministrationAudit.where(target_id: @mentee.id).to_json.include?('Replacement123')
  end

  test 'bulk status is atomic if any account is protected or stale' do
    versions = { @mentee.id.to_s => @mentee.lock_version, @super.id.to_s => @super.lock_version }
    post '/api/v1/admin/users/bulk-status', headers: auth_headers(@admin), params: { user_ids: [@mentee.id, @super.id], account: { is_active: false }, versions: versions }, as: :json
    assert_response :forbidden
    assert @mentee.reload.is_active?
    assert @super.reload.is_active?
    post '/api/v1/admin/users/bulk-status', headers: auth_headers(@admin), params: { user_ids: [@mentee.id], account: { is_active: false }, versions: { @mentee.id.to_s => @mentee.lock_version } }, as: :json
    assert_response :ok
    assert_not @mentee.reload.is_active?
  end

  test 'exports respect filters and prevent CSV formula injection' do
    @mentee.update!(full_name: '=HYPERLINK("bad")')
    get '/api/v1/admin/users/export', headers: auth_headers(@admin), params: { q: @mentee.email }
    assert_response :ok
    csv = CSV.parse(response.body, headers: true)
    assert_equal 1, csv.size
    assert csv.first['full_name'].start_with?("'=")
    assert_not_includes response.body, 'hashed_password'
    assert_not_includes response.body, 'secret123'
  end

  test 'CSV preview creates nothing and valid imports are atomic without privileged roles' do
    rows = [['CSV User', 'csv-new@example.test', '+256700002003', 'mentee', 'School', 'ImportPass123']]
    tempfile, file = csv_file(rows)
    begin
      before = User.count
      post '/api/v1/admin/users/import-preview', headers: auth_headers(@admin), params: { file: file }
      assert_response :ok
      assert response.parsed_body['valid']
      assert_equal before, User.count
      assert_not_includes response.body, 'ImportPass123'
      post '/api/v1/admin/users/import', headers: auth_headers(@admin), params: { file: Rack::Test::UploadedFile.new(tempfile.path, 'text/csv') }
      assert_response :created
      assert User.find_by!(email: 'csv-new@example.test').authenticate('ImportPass123')
    ensure
      tempfile.close!
    end
    rows = [['Good User', 'csv-good@example.test', '+256700002004', 'mentee', '', 'ImportPass123'], ['Forbidden', 'csv-staff@example.test', '+256700002005', 'super_admin', '', 'ImportPass123']]
    tempfile, file = csv_file(rows)
    begin
      post '/api/v1/admin/users/import', headers: auth_headers(@super), params: { file: file }
      assert_response :unprocessable_entity
      assert_not User.exists?(email: 'csv-good@example.test')
      assert_not User.exists?(email: 'csv-staff@example.test')
    ensure
      tempfile.close!
    end
  end

  test 'last active super admin cannot deactivate through personal settings' do
    # Isolate the invariant from other pre-existing QA accounts in this test database.
    User.where.not(id: @super.id).update_all(is_active: false)
    post '/api/v1/me/settings/deactivate', headers: auth_headers(@super), params: { account: { current_password: 'secret123', confirmation: 'DEACTIVATE' } }, as: :json
    assert_response :unprocessable_entity
    assert @super.reload.is_active?
  end

  test 'management grants are enforced and custom role grants require an administrator role' do
    @admin.role.update!(permissions: ['users.read', 'roles.read'])
    post '/api/v1/admin/users', headers: auth_headers(@admin), params: { user: payload }, as: :json
    assert_response :forbidden
    get '/api/v1/admin/users', headers: auth_headers(@admin)
    assert_response :ok
    get '/api/v1/admin/system_settings', headers: auth_headers(@admin)
    assert_response :forbidden
    custom = Role.create!(name: 'import_assistant', permissions: ['users.create'])
    @admin.additional_roles << custom
    assert @admin.reload.management_permission?('users.create')
    @mentee.additional_roles << custom
    get '/api/v1/admin/users', headers: auth_headers(@mentee)
    assert_response :forbidden
  end
end
