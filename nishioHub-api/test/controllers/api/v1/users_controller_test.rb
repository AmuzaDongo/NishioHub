require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @role = create_role("mentor")
    @user = create_user(email: "ada@example.com", role: @role)
  end

  test "me returns the current user" do
    get "/api/v1/users/me", headers: auth_headers(@user)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @user.id, body["id"]
    assert_equal "ada@example.com", body["email"]
    assert_equal "mentor", body.dig("role", "name")
  end

  test "index returns only the current user" do
    create_user(email: "other@example.com", role: @role, full_name: "Other")

    get "/api/v1/users", headers: auth_headers(@user)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal @user.id, body.first["id"]
  end

  test "me rejects a missing token" do
    get "/api/v1/users/me"

    assert_response :unauthorized
    assert_equal "Invalid token", JSON.parse(response.body)["detail"]
  end

  test "me returns 404 for a token whose user no longer exists" do
    token = JsonWebToken.encode({ sub: "ghost@example.com" }, exp: 1.hour.from_now)

    get "/api/v1/users/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :not_found
    assert_equal "User not found", JSON.parse(response.body)["detail"]
  end

  test "verify_email marks the user verified and returns the API confirmation" do
    token = EmailToken.encode(@user.email)

    get "/api/v1/users/verify-email", params: { token: token }

    assert_response :ok
    assert_equal "Email verified. You can now sign in to NishioHub.", response.parsed_body["detail"]
    assert @user.reload.is_verified
  end

  test "verify_email rejects a bad token" do
    get "/api/v1/users/verify-email", params: { token: "bad" }

    assert_response :bad_request
    assert_equal "Invalid or expired token", JSON.parse(response.body)["detail"]
  end
end
