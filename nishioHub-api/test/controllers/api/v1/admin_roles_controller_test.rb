require 'test_helper'
class Api::V1::AdminRolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: create_role('admin'), email: 'roles-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'roles-super@example.test')
  end

  test 'custom roles validate and persist permissions with audit records' do
    post '/api/v1/admin/roles', headers: auth_headers(@admin), params: { role: { name: 'account_support', description: 'Support users', permissions: ['users.read'] } }, as: :json
    assert_response :created
    role = Role.find(response.parsed_body['id'])
    assert_equal ['users.read'], role.permissions
    patch "/api/v1/admin/roles/#{role.id}", headers: auth_headers(@admin), params: { role: { description: 'Updated support', permissions: ['users.read', 'users.export'], lock_version: role.lock_version } }, as: :json
    assert_response :ok
    assert_equal 'Updated support', role.reload.description
    assert AdministrationAudit.exists?(target_id: role.id, action: 'role.updated')
    delete "/api/v1/admin/roles/#{role.id}", headers: auth_headers(@admin), params: { lock_version: role.lock_version }, as: :json
    assert_response :no_content
  end

  test 'built in roles are protected through new and legacy endpoints' do
    patch "/api/v1/admin/roles/#{@admin.role_id}", headers: auth_headers(@admin), params: { role: { permissions: [], lock_version: @admin.role.lock_version } }, as: :json
    assert_response :forbidden
    patch "/api/v1/roles/#{@super.role_id}", headers: auth_headers(@admin), params: { name: 'renamed' }, as: :json
    assert_response :forbidden
    delete "/api/v1/roles/#{@admin.role_id}", headers: auth_headers(@admin)
    assert_response :unprocessable_entity
    post '/api/v1/roles', headers: auth_headers(@admin), params: { name: 'superadmin' }, as: :json
    assert_response :unprocessable_entity
    assert_equal 'super_admin', @super.role.reload.name
  end

  test 'assigned custom roles cannot be deleted and unknown grants cannot be saved' do
    role = Role.create!(name: 'assigned_support', permissions: ['users.read'])
    @admin.additional_roles << role
    delete "/api/v1/admin/roles/#{role.id}", headers: auth_headers(@super), params: { lock_version: role.lock_version }, as: :json
    assert_response :unprocessable_entity
    patch "/api/v1/admin/roles/#{role.id}", headers: auth_headers(@super), params: { role: { permissions: ['unknown.grant'], lock_version: role.lock_version } }, as: :json
    assert_response :unprocessable_entity
    assert_equal ['users.read'], role.reload.permissions
  end

  test 'only super admin can change admin grants and changes revoke existing sessions' do
    token = auth_headers(@admin)
    refresh = RefreshToken.issue_for(@admin)
    patch "/api/v1/admin/roles/#{@admin.role_id}", headers: auth_headers(@super), params: { role: { permissions: ['users.read', 'roles.read'], lock_version: @admin.role.lock_version } }, as: :json
    assert_response :ok
    assert refresh.reload.revoked
    get '/api/v1/admin/users', headers: token
    assert_response :unauthorized
    get '/api/v1/admin/users', headers: auth_headers(@admin.reload)
    assert_response :ok
    post '/api/v1/admin/users', headers: auth_headers(@admin), params: { user: {} }, as: :json
    assert_response :forbidden
  end

  test 'role managers cannot grant permissions they do not hold' do
    @admin.role.update!(permissions: ['roles.read', 'roles.manage'])
    post '/api/v1/admin/roles', headers: auth_headers(@admin), params: { role: { name: 'grant_escalation', permissions: ['users.create'] } }, as: :json
    assert_response :forbidden
    assert_not Role.exists?(name: 'grant_escalation')
  end
end
