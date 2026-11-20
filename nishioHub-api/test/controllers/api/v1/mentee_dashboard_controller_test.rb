require "test_helper"

class Api::V1::MenteeDashboardControllerTest < ActionDispatch::IntegrationTest
  def mentee(email = "learner@example.com", role = "mentee")
    User.create!(full_name: "Learner", email: email,
                 phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}",
                 password: "secret123", role: create_role(role))
  end

  test "dashboard requires a signed in mentee" do
    get "/api/v1/me/mentee_dashboard"
    assert_response :unauthorized
    get "/api/v1/me/mentee_dashboard", headers: auth_headers(mentee("mentor@example.com", "mentor"))
    assert_response :forbidden
  end

  test "new mentees receive honest empty states" do
    get "/api/v1/me/mentee_dashboard", headers: auth_headers(mentee)
    assert_response :ok
    body = response.parsed_body
    assert_equal "Learner", body.dig("profile", "name")
    assert_nil body["mentor"]
    assert_nil body["next_session"]
    assert_equal [], body["achievements"]
    assert_equal 0, body["session_progress"]
  end

  test "profile edits persist and ignore another user id" do
    learner = mentee
    other = mentee("other@example.com")
    patch "/api/v1/me/mentee_profile", headers: auth_headers(learner), params: {
      profile: { school: "Nakasero", grade: "P6", bio: "I enjoy science", user_id: other.id }
    }, as: :json
    assert_response :ok
    assert_equal "Nakasero", learner.reload.mentee_profile.school
    assert_nil other.reload.mentee_profile
    get "/api/v1/me/mentee_dashboard", headers: auth_headers(learner)
    assert_equal "P6", response.parsed_body.dig("profile", "grade")
  end

  test "goals validate input and are isolated by owner" do
    learner = mentee
    other = mentee("other@example.com")
    post "/api/v1/me/mentee_goals", headers: auth_headers(learner), params: { goal: { title: " " } }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/me/mentee_goals", headers: auth_headers(learner), params: { goal: { title: "Build my first app" } }, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    patch "/api/v1/me/mentee_goals/#{id}", headers: auth_headers(other), params: { goal: { completed: true } }, as: :json
    assert_response :not_found
    patch "/api/v1/me/mentee_goals/#{id}", headers: auth_headers(learner), params: { goal: { completed: true } }, as: :json
    assert_response :ok
    get "/api/v1/me/mentee_dashboard", headers: auth_headers(learner)
    assert_equal 100, response.parsed_body["goal_progress"]
    assert_includes response.parsed_body["achievements"], "Goal Setter"
    get "/api/v1/me/mentee_dashboard", headers: auth_headers(other)
    assert_empty response.parsed_body["goals"]
  end

  test "session summary includes only owned bookings and future active sessions" do
    learner = mentee
    other = mentee("other@example.com")
    mentor = mentee("mentor@example.com", "mentor")
    mentor.create_mentor_profile!(title: "Science Mentor")
    service = create_service(mentor: mentor)
    create_booking(service: service, mentee: learner, mentor: mentor, status: "completed", scheduled_at: 1.day.ago)
    next_booking = create_booking(service: service, mentee: learner, mentor: mentor, status: "confirmed")
    create_booking(service: service, mentee: learner, mentor: mentor, status: "cancelled")
    create_booking(service: service, mentee: other, mentor: mentor, status: "completed")
    get "/api/v1/me/mentee_dashboard", headers: auth_headers(learner)
    assert_response :ok
    assert_equal 1, response.parsed_body["completed_sessions"]
    assert_equal 1, response.parsed_body["upcoming_sessions"]
    assert_equal 20, response.parsed_body["session_progress"]
    assert_equal next_booking.id, response.parsed_body.dig("next_session", "id")
    assert_equal mentor.id, response.parsed_body.dig("mentor", "id")
    assert_includes response.parsed_body["achievements"], "First session"
  end
end
