require "test_helper"

class Api::V1::SettingsControllerTest < ActionDispatch::IntegrationTest
  def person(email = "settings@example.test")
    User.create!(full_name: "Settings Learner", email: email, password: "OriginalPass123", role: create_role("mentee"),
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}")
  end

  test "all settings endpoints require authentication" do
    get "/api/v1/me/settings"
    assert_response :unauthorized
    patch "/api/v1/me/settings/profile", params: { profile: { full_name: "Spoof" } }, as: :json
    assert_response :unauthorized
    patch "/api/v1/me/settings/preferences", params: { preferences: { appearance: "dark" } }, as: :json
    assert_response :unauthorized
    patch "/api/v1/me/settings/password", params: {}, as: :json
    assert_response :unauthorized
    post "/api/v1/me/settings/avatar"
    assert_response :unauthorized
    get "/api/v1/me/settings/export"
    assert_response :unauthorized
    post "/api/v1/me/settings/deactivate", params: {}, as: :json
    assert_response :unauthorized
  end

  test "profile saves only owned fields and invalid school rolls back the entire update" do
    user = person
    other = person("other-settings@example.test")
    patch "/api/v1/me/settings/profile", headers: auth_headers(user), params: { profile: { full_name: "Joyce Updated", school: "Nakasero Primary School", grade: "P.6", bio: "I enjoy learning.", role_id: create_role("admin").id, user_id: other.id, is_active: false } }, as: :json
    assert_response :ok
    assert_equal "Joyce Updated", user.reload.full_name
    assert_equal "mentee", user.role.name
    assert user.is_active
    assert_equal "P.6", user.mentee_profile.grade
    assert_equal "Settings Learner", other.reload.full_name
    patch "/api/v1/me/settings/profile", headers: auth_headers(user), params: { profile: { full_name: "Must Roll Back", school: "" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "Joyce Updated", user.reload.full_name
    assert_equal "Nakasero Primary School", user.mentee_profile.reload.school
  end

  test "email changes require password rotate sessions and preserve unique email" do
    user = person
    headers = auth_headers(user)
    user.create_mentee_profile!(school: "School", grade: "P.6")
    old_refresh = RefreshToken.issue_for(user)
    patch "/api/v1/me/settings/profile", headers: headers, params: { profile: { email: "new-settings@example.test" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "settings@example.test", user.reload.email
    patch "/api/v1/me/settings/profile", headers: headers, params: { profile: { email: " NEW-SETTINGS@example.test ", current_password: "OriginalPass123" } }, as: :json
    assert_response :ok
    new_token = response.parsed_body.dig("session", "access_token")
    assert new_token.present?
    assert old_refresh.reload.revoked
    assert_equal "new-settings@example.test", user.reload.email
    get "/api/v1/me/settings", headers: { "Authorization" => "Bearer #{new_token}" }
    assert_response :ok
    get "/api/v1/me/settings", headers: headers
    assert_response :not_found
    person("settings@example.test")
    get "/api/v1/me/settings", headers: headers
    assert_response :unauthorized
    other = person("taken-settings@example.test")
    patch "/api/v1/me/settings/profile", headers: { "Authorization" => "Bearer #{new_token}" }, params: { profile: { email: other.email, current_password: "OriginalPass123" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "new-settings@example.test", user.reload.email
  end

  test "password change rejects invalid values and revokes access and refresh tokens" do
    user = person
    headers = auth_headers(user)
    old_refresh = RefreshToken.issue_for(user)
    [{ current_password: "wrong", new_password: "UpdatedPass123", password_confirmation: "UpdatedPass123" },
     { current_password: "OriginalPass123", new_password: "short", password_confirmation: "short" },
     { current_password: "OriginalPass123", new_password: "UpdatedPass123", password_confirmation: "Mismatch123" }].each do |values|
      patch "/api/v1/me/settings/password", headers: headers, params: { password_change: values }, as: :json
      assert_response :unprocessable_entity
    end
    patch "/api/v1/me/settings/password", headers: headers, params: { password_change: { current_password: "OriginalPass123", new_password: "UpdatedPass123", password_confirmation: "UpdatedPass123" } }, as: :json
    assert_response :ok
    session = response.parsed_body["session"]
    assert user.reload.authenticate("UpdatedPass123")
    assert_not user.authenticate("OriginalPass123")
    assert old_refresh.reload.revoked
    get "/api/v1/me/settings", headers: headers
    assert_response :unauthorized
    get "/api/v1/me/settings", headers: { "Authorization" => "Bearer #{session['access_token']}" }
    assert_response :ok
    post "/api/v1/auth/refresh", params: { refresh_token: old_refresh.token }, as: :json
    assert_response :unauthorized
    post "/api/v1/auth/refresh", params: { refresh_token: session["refresh_token"] }, as: :json
    assert_response :ok
  end

  test "preferences validate partial updates and hide activity and new contact requests" do
    user = person
    stranger = person("stranger-settings@example.test")
    user.update!(last_active_at: Time.current)
    patch "/api/v1/me/settings/preferences", headers: auth_headers(user), params: { preferences: { appearance: "dark", show_online_status: false, allow_contact_requests: false, weekly_learning_minutes: 180, learning_format: "practical", mentorship_focus: "Software careers", session_preference: "either" } }, as: :json
    assert_response :ok
    assert_equal 180, response.parsed_body.dig("preferences", "weekly_learning_minutes")
    assert_equal false, ConversationSerializer.person_json(user.reload)[:online]
    assert_nil ConversationSerializer.person_json(user)[:last_active_at]
    get "/api/v1/conversations/contacts", headers: auth_headers(stranger), params: { q: "Settings Learner" }
    assert_not_includes response.parsed_body.map { |row| row["id"] }, user.id
    post "/api/v1/conversations", headers: auth_headers(stranger), params: { participant_ids: [user.id] }, as: :json
    assert_response :unprocessable_entity
    patch "/api/v1/me/settings/preferences", headers: auth_headers(user), params: { preferences: { appearance: "invalid", weekly_learning_minutes: 0 } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "dark", user.account_setting.reload.appearance
    patch "/api/v1/me/settings/preferences", headers: auth_headers(user), params: { preferences: { show_online_status: "false" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "existing contacts remain available when new contact requests are disabled" do
    user = person
    other = person("known-settings@example.test")
    conversation = Conversation.create!(creator: user, kind: "direct", direct_key: [user.id, other.id].sort.join(":"))
    [user, other].each { |member| conversation.conversation_memberships.create!(user: member) }
    user.create_account_setting!(allow_contact_requests: false)
    post "/api/v1/conversations", headers: auth_headers(other), params: { participant_ids: [user.id] }, as: :json
    assert_response :ok
    assert_equal conversation.id, response.parsed_body["id"]
  end

  test "avatar checks image bytes and size and appears in account and chat serializers" do
    user = person
    post "/api/v1/me/settings/avatar", headers: auth_headers(user), params: { avatar: Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/avatar.png"), "image/png") }
    assert_response :ok
    assert user.reload.avatar.attached?
    assert response.parsed_body.dig("user", "avatar").present?
    get "/api/v1/users/me", headers: auth_headers(user)
    assert response.parsed_body["avatar"].present?
    post "/api/v1/me/settings/avatar", headers: auth_headers(user), params: { avatar: Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "image/png") }
    assert_response :unprocessable_entity
    post "/api/v1/me/settings/avatar", headers: auth_headers(user), params: { avatar: "a-signed-blob-id" }, as: :json
    assert_response :unprocessable_entity
  end

  test "export contains own data and excludes passwords tokens and other accounts" do
    user = person
    other = person("other-export@example.test")
    user.notifications.create!(title: "Own private alert", message: "Own data")
    other.notifications.create!(title: "Other secret alert", message: "Never export this")
    RefreshToken.issue_for(user)
    get "/api/v1/me/settings/export", headers: auth_headers(user)
    assert_response :ok
    assert_includes response.headers["Content-Disposition"], "attachment"
    body = JSON.parse(response.body)
    assert_equal user.email, body.dig("account", "email")
    assert_includes response.body, "Own private alert"
    assert_not_includes response.body, "Other secret alert"
    assert_not_includes response.body, "hashed_password"
    assert_not_includes response.body, "refresh_token"
  end

  test "deactivation requires password and confirmation and blocks login refresh and existing access" do
    user = person
    headers = auth_headers(user)
    refresh = RefreshToken.issue_for(user)
    post "/api/v1/me/settings/deactivate", headers: headers, params: { account: { current_password: "wrong", confirmation: "DEACTIVATE" } }, as: :json
    assert_response :unprocessable_entity
    assert user.reload.is_active
    post "/api/v1/me/settings/deactivate", headers: headers, params: { account: { current_password: "OriginalPass123", confirmation: "no" } }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/me/settings/deactivate", headers: headers, params: { account: { current_password: "OriginalPass123", confirmation: "DEACTIVATE" } }, as: :json
    assert_response :ok
    assert_not user.reload.is_active
    assert refresh.reload.revoked
    get "/api/v1/me/settings", headers: headers
    assert_response :unauthorized
    post "/api/v1/auth/login", params: { email: user.email, password: "OriginalPass123" }, as: :json
    assert_response :unauthorized
    post "/api/v1/auth/refresh", params: { refresh_token: refresh.token }, as: :json
    assert_response :unauthorized
  end
end
