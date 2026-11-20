require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mentee = create_role("mentee")
    @user_role = create_role("user")
  end

  test "register creates a user and returns the UserOut shape" do
    post "/api/v1/auth/register", params: {
      full_name: "Ada Lovelace",
      email: "ada@example.com",
      password: "secret123",
      phone_number: "+256700001800",
      role_id: @mentee.id
    }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Ada Lovelace", body["full_name"]
    assert_equal "ada@example.com", body["email"]
    assert_equal true, body["is_active"]
    assert_equal({ "id" => @mentee.id, "name" => "mentee" }, body["role"])
    assert User.exists?(email: "ada@example.com")
  end

  test "register rejects a duplicate email" do
    create_user(email: "ada@example.com", role: @mentee)

    post "/api/v1/auth/register", params: {
      full_name: "Another Ada",
      email: "ada@example.com",
      password: "secret123",
      phone_number: "+256700001800",
      role_id: @mentee.id
    }, as: :json

    assert_response :bad_request
    assert_equal "Email already registered", JSON.parse(response.body)["detail"]
  end

  test "register rejects an unknown role_id" do
    post "/api/v1/auth/register", params: {
      full_name: "No Role",
      email: "norole@example.com",
      password: "secret123",
      phone_number: "+256700001800",
      role_id: 999
    }, as: :json

    assert_response :bad_request
    assert_equal "Invalid role_id", JSON.parse(response.body)["detail"]
  end

  test "register defaults a blank role_id to the configured mentee role" do
    post "/api/v1/auth/register", params: {
      full_name: "Default Role",
      email: "default@example.com",
      phone_number: "+256700001801",
      password: "secret123"
    }, as: :json

    assert_response :ok
    assert_equal "mentee", JSON.parse(response.body).dig("role", "name")
  end

  test "login accepts form-encoded username and returns both tokens" do
    create_user(email: "ada@example.com", role: @mentee)

    post "/api/v1/auth/login", params: {
      username: "ada@example.com",
      password: "secret123"
    }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_equal "bearer", body["token_type"]
  end

  test "login rejects bad credentials" do
    create_user(email: "ada@example.com", role: @mentee)

    post "/api/v1/auth/login", params: { username: "ada@example.com", password: "wrong" }

    assert_response :unauthorized
    assert_equal "Invalid credentials", JSON.parse(response.body)["detail"]
  end

  test "refresh issues a new access token" do
    user = create_user(email: "ada@example.com", role: @mentee)
    refresh = RefreshToken.issue_for(user)

    post "/api/v1/auth/refresh", params: { refresh_token: refresh.token }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["access_token"].present?
    assert_equal "bearer", body["token_type"]
  end

  test "refresh fails after logout" do
    user = create_user(email: "ada@example.com", role: @mentee)
    refresh = RefreshToken.issue_for(user)

    post "/api/v1/auth/logout", params: { refresh_token: refresh.token }
    assert_response :ok

    post "/api/v1/auth/refresh", params: { refresh_token: refresh.token }
    assert_response :unauthorized
    assert_equal "Invalid token", JSON.parse(response.body)["detail"]
  end

  test "logout returns 404 for an unknown token" do
    post "/api/v1/auth/logout", params: { refresh_token: "missing" }

    assert_response :not_found
    assert_equal "Token not found", JSON.parse(response.body)["detail"]
  end
end
