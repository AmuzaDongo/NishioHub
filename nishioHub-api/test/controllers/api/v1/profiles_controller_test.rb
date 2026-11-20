require "test_helper"

class Api::V1::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @role = create_role("mentee")
    @user = create_user(email: "ada@example.com", role: @role)
    @profile = Profile.create!(
      phone_number: "+15550001", gender: "female", birth_date: Date.new(1990, 1, 1),
      address: "1 Main St", city: "Austin", country: "US", user: @user
    )
  end

  test "index returns profiles" do
    get "/api/v1/users/profile"

    assert_response :ok
    assert_equal 1, JSON.parse(response.body).length
  end

  test "create returns 201" do
    other = create_user(email: "other@example.com", role: @role, full_name: "Other")

    post "/api/v1/users/profile", params: {
      phone_number: "+15550002", gender: "male", birth_date: "1991-02-02",
      address: "2 Main St", city: "Dallas", country: "US", user_id: other.id
    }, as: :json

    assert_response :created
    assert_equal other.id, JSON.parse(response.body)["user_id"]
  end

  test "show returns 404 for a missing profile" do
    get "/api/v1/users/profile/999"

    assert_response :not_found
    assert_equal "Profile not found", JSON.parse(response.body)["detail"]
  end

  test "update changes the address" do
    put "/api/v1/users/profile/#{@profile.id}", params: {
      phone_number: "+15550001", gender: "female", birth_date: "1990-01-01",
      address: "9 New St", city: "Austin", country: "US", user_id: @user.id
    }, as: :json

    assert_response :ok
    assert_equal "9 New St", JSON.parse(response.body)["address"]
  end

  test "destroy returns the detail envelope" do
    delete "/api/v1/users/profile/#{@profile.id}"

    assert_response :ok
    assert_equal "Profile deleted", JSON.parse(response.body)["detail"]
  end

  test "upload_image stores an image path" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/avatar.png"), "image/png")

    post "/api/v1/users/profile/#{@profile.id}/upload-image", params: { file: file }

    assert_response :ok
    assert_match %r{\Amedia/profiles/}, JSON.parse(response.body)["profile_picture"]
  end

  test "upload_image rejects a non-image" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/plain")

    post "/api/v1/users/profile/#{@profile.id}/upload-image", params: { file: file }

    assert_response :bad_request
    assert_equal "File must be an image", JSON.parse(response.body)["detail"]
  end
end
