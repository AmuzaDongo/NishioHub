require "test_helper"

class Api::V1::Me::MentorProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mentor = create_mentor(email: "mentor@example.com", full_name: "Alex Morgan", title: "Senior Engineer", rate: 150, skills: ["React"])
    @mentee = create_mentee(email: "mentee@example.com", full_name: "Carlos Rodriguez")
  end

  test "GET self creates a profile idempotently for a fresh mentor" do
    fresh = create_user(role: create_role("mentor"), email: "fresh@example.com", full_name: "Fresh Mentor")
    assert_nil fresh.mentor_profile

    get "/api/v1/me/mentor_profile", headers: auth_headers(fresh)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Fresh Mentor", body["name"]
    assert_equal "Mentor", body["headline"]
    assert fresh.reload.mentor_profile.present?
    first_id = fresh.mentor_profile.id

    get "/api/v1/me/mentor_profile", headers: auth_headers(fresh)

    assert_response :ok
    assert_equal first_id, fresh.reload.mentor_profile.id
  end

  test "GET self returns the private self view" do
    get "/api/v1/me/mentor_profile", headers: auth_headers(@mentor)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @mentor.email, body["email"]
    assert_equal true, body["is_published"]
    assert_equal "Alex Morgan", body["name"]
    assert_equal "Senior Engineer", body["headline"]
    assert_equal 150.0, body["hourly_rate"]
    assert_equal ["React"], body["skills"]
  end

  test "PATCH self updates the profile and skills" do
    patch "/api/v1/me/mentor_profile",
          params: {
            name: "Alex Updated",
            headline: "Principal Engineer",
            bio: "A newly updated mentor bio.",
            hourly_rate: 175,
            currency: "EUR",
            languages: ["English", "French"],
            years_of_experience: 12,
            timezone: "Europe/London",
            skills: ["React", "Leadership"],
            accepting_bookings: false
          },
          headers: auth_headers(@mentor), as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Alex Updated", body["name"]
    assert_equal "Principal Engineer", body["headline"]
    assert_equal "A newly updated mentor bio.", body["bio"]
    assert_equal 175.0, body["hourly_rate"]
    assert_equal "EUR", body["currency"]
    assert_equal ["English", "French"], body["languages"]
    assert_equal 12, body["years_of_experience"]
    assert_equal "Europe/London", body["timezone"]
    assert_equal ["React", "Leadership"], body["skills"]
    assert_equal false, body["accepting_bookings"]
    assert_equal "Alex Updated", @mentor.reload.full_name
  end

  test "PATCH self rejects unknown fields" do
    patch "/api/v1/me/mentor_profile",
          params: { is_admin: true },
          headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
    assert_match(/Unknown fields/, JSON.parse(response.body)["detail"])
  end

  test "PATCH self rejects a blank name" do
    patch "/api/v1/me/mentor_profile", params: { name: "" }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH self rejects a blank headline" do
    patch "/api/v1/me/mentor_profile", params: { headline: "" }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH self rejects an overlong bio" do
    patch "/api/v1/me/mentor_profile", params: { bio: "a" * 2001 }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH self rejects a negative hourly rate" do
    patch "/api/v1/me/mentor_profile", params: { hourly_rate: -1 }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH self rejects negative years of experience" do
    patch "/api/v1/me/mentor_profile", params: { years_of_experience: -1 }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH self rejects an invalid timezone" do
    patch "/api/v1/me/mentor_profile", params: { timezone: "Not/AZone" }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "PATCH self rejects languages that are not an array" do
    patch "/api/v1/me/mentor_profile", params: { languages: "English" }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "mentee gets 403 on the self endpoint" do
    get "/api/v1/me/mentor_profile", headers: auth_headers(@mentee)

    assert_response :forbidden
    assert_equal "Mentor access required", JSON.parse(response.body)["detail"]
  end

  test "unauthenticated request gets 401" do
    get "/api/v1/me/mentor_profile"

    assert_response :unauthorized
  end

  test "public mentor JSON hides private fields" do
    get "/api/v1/mentor_profiles/#{@mentor.id}"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_not body.key?("email")
    assert_not body.key?("is_published")
    assert_equal "Alex Morgan", body["name"]
  end

  test "public mentors JSON hides private fields" do
    get "/api/v1/mentors/#{@mentor.id}"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_not body.key?("email")
    assert_not body.key?("is_published")
  end

  test "public mentor_profiles returns 404 for a missing mentor" do
    get "/api/v1/mentor_profiles/999999"

    assert_response :not_found
  end

  test "avatar upload returns an absolute avatar_url" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/avatar.png"), "image/png")

    post "/api/v1/me/mentor_profile/avatar", params: { avatar: file }, headers: auth_headers(@mentor)

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["avatar_url"].present?
    assert_match(%r{\Ahttp://}, body["avatar_url"])
    assert @mentor.mentor_profile.reload.avatar.attached?
  end

  test "avatar upload rejects a non-image" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/plain")

    post "/api/v1/me/mentor_profile/avatar", params: { avatar: file }, headers: auth_headers(@mentor)

    assert_response :unprocessable_entity
    assert_equal "Avatar must be a JPEG, PNG, or WebP image", JSON.parse(response.body)["detail"]
  end

  test "avatar upload rejects a file larger than 5 MB" do
    large = Tempfile.new(["large", ".png"])
    large.write("a" * (6 * 1024 * 1024))
    large.rewind
    file = Rack::Test::UploadedFile.new(large.path, "image/png")

    post "/api/v1/me/mentor_profile/avatar", params: { avatar: file }, headers: auth_headers(@mentor)

    assert_response :unprocessable_entity
    assert_equal "Avatar must be smaller than 5 MB", JSON.parse(response.body)["detail"]
  ensure
    large&.close!
  end

  test "replacing an avatar purges the previous blob" do
    profile = @mentor.mentor_profile
    profile.avatar.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "first.png", content_type: "image/png"
    )
    old_blob_id = profile.avatar.blob.id

    replacement = Rack::Test::UploadedFile.new(Rails.root.join("db/seed_assets/sarah.jpg"), "image/jpeg")
    post "/api/v1/me/mentor_profile/avatar", params: { avatar: replacement }, headers: auth_headers(@mentor)

    assert_response :ok
    assert_not ActiveStorage::Blob.exists?(old_blob_id)
    assert @mentor.mentor_profile.reload.avatar.attached?
  end

  test "avatar delete returns 204 and clears avatar_url" do
    @mentor.mentor_profile.avatar.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "avatar.png", content_type: "image/png"
    )

    delete "/api/v1/me/mentor_profile/avatar", headers: auth_headers(@mentor)

    assert_response :no_content
    assert_not @mentor.mentor_profile.reload.avatar.attached?

    get "/api/v1/me/mentor_profile", headers: auth_headers(@mentor)

    assert_response :ok
    assert_nil JSON.parse(response.body)["avatar_url"]
  end
end
