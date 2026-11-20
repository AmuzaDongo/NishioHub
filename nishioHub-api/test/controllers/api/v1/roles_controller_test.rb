require "test_helper"

class Api::V1::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_role = create_role("admin")
    @mentor_role = create_role("mentor")
    @mentee_role = create_role("mentee")
    @admin = create_user(email: "admin@example.com", role: @admin_role, full_name: "Admin")
    @mentee = create_user(email: "mentee@example.com", role: @mentee_role, full_name: "Mentee")
    @no_role = create_user(email: "norole@example.com", role: nil, full_name: "No Role")
  end

  test "mentor_mentee is public" do
    get "/api/v1/roles/mentor-mentee"

    assert_response :ok
    names = JSON.parse(response.body).map { |role| role["name"] }
    assert_equal %w[mentor mentee], names
  end

  test "index is allowed for an admin" do
    get "/api/v1/roles", headers: auth_headers(@admin)

    assert_response :ok
    assert_equal Role.count, JSON.parse(response.body).length
  end

  test "index returns 403 for a regular user" do
    get "/api/v1/roles", headers: auth_headers(@mentee)

    assert_response :forbidden
    assert_equal "Administrator access required", JSON.parse(response.body)["detail"]
  end

  test "index returns 403, not an exception, for a user with no role" do
    get "/api/v1/roles", headers: auth_headers(@no_role)

    assert_response :forbidden
    assert_equal "Administrator access required", JSON.parse(response.body)["detail"]
  end

  test "create returns 201 for an admin" do
    post "/api/v1/roles", params: { name: "reviewer" }, headers: auth_headers(@admin), as: :json

    assert_response :created
    assert_equal "reviewer", JSON.parse(response.body)["name"]
  end

  test "create rejects a duplicate name" do
    post "/api/v1/roles", params: { name: "mentor" }, headers: auth_headers(@admin), as: :json

    assert_response :bad_request
    assert_equal "Role 'mentor' already exists.", JSON.parse(response.body)["detail"]
  end

  test "update returns 404 for a missing role" do
    put "/api/v1/roles/999", params: { name: "x" }, headers: auth_headers(@admin), as: :json

    assert_response :not_found
    assert_equal "Role with ID 999 not found.", JSON.parse(response.body)["detail"]
  end

  test "destroy protects a built-in role" do
    delete "/api/v1/roles/#{@mentee_role.id}", headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert Role.exists?(@mentee_role.id)
  end
end
