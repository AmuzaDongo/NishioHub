require "test_helper"

class Api::V1::MiscControllerTest < ActionDispatch::IntegrationTest
  test "dashboard and statistics require administrator access" do
    get "/api/v1/dashboard"
    assert_response :unauthorized
    get "/api/v1/statistics"
    assert_response :unauthorized
    member = create_mentee
    get "/api/v1/statistics", headers: auth_headers(member)
    assert_response :forbidden
    admin = create_user(role: create_role('admin'), email: 'misc-admin@example.test')
    get "/api/v1/statistics", headers: auth_headers(admin)
    assert_response :ok
    assert_equal User.count, response.parsed_body["total_users"]
    get "/api/v1/dashboard", headers: auth_headers(admin)
    assert_response :ok
    assert_equal User.count, response.parsed_body['metrics'].find { |item| item['key'] == 'users' }['value']
  end

  test "notifications reject unauthenticated reads and writes" do
    post "/api/v1/notifications", params: { title: "Hello", message: "World" }
    assert_response :unauthorized
    get "/api/v1/notifications"
    assert_response :unauthorized
  end

  test "uploads stores a file and returns its basename" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/plain")

    post "/api/v1/uploads", params: { file: file }

    assert_response :ok
    assert_equal "notes.txt", JSON.parse(response.body)["filename"]
  end

  test "uploads sanitizes a path traversal filename" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/plain", original_filename: "../../evil.txt")

    post "/api/v1/uploads", params: { file: file }

    assert_response :ok
    assert_equal "evil.txt", JSON.parse(response.body)["filename"]
  end
end
