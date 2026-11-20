require "test_helper"

class Api::V1::MentorshipControllerTest < ActionDispatch::IntegrationTest
  def user_for(role, email)
    User.create!(full_name: "#{role.capitalize} User", email: email,
                 phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}",
                 password: "secret123", role: create_role(role))
  end

  setup do
    @mentor = user_for("mentor", "owner@example.com")
    @mentor.create_mentor_profile!(title: "Science Educator")
    @other = user_for("mentor", "other@example.com")
    @other.create_mentor_profile!(title: "Other Mentor")
    @mentee = user_for("mentee", "learner@example.com")
  end

  test "all mentorship endpoints require a mentor" do
    get "/api/v1/me/mentorship"
    assert_response :unauthorized
    get "/api/v1/me/mentorship", headers: auth_headers(@mentee)
    assert_response :forbidden
    post "/api/v1/me/mentorship/goals", headers: auth_headers(@mentee), params: { goal: { title: "Denied" } }, as: :json
    assert_response :forbidden
    post "/api/v1/me/mentorship/resources", headers: auth_headers(@mentee), params: { resource: { title: "Denied", url: "https://example.com" } }, as: :json
    assert_response :forbidden
  end

  test "empty dashboard does not invent impact or connections" do
    get "/api/v1/me/mentorship", headers: auth_headers(@mentor)
    assert_response :ok
    body = response.parsed_body
    assert_empty body["mentees"]
    assert_empty body["sessions"]
    assert_empty body["goals"]
    assert_empty body["resources"]
    assert_nil body.dig("stats", "rating")
    assert_equal 0, body.dig("stats", "hours")
    assert_equal 0, body.dig("stats", "sessions")
  end

  test "dashboard includes only owned sessions and actual completed hours" do
    service = create_service(mentor: @mentor)
    other_service = create_service(mentor: @other)
    @mentee.create_mentee_profile!(school: "Nakasero", grade: "P6", bio: "Private biography")
    @mentee.mentee_goals.create!(title: "Private learning goal")
    create_booking(service: service, mentor: @mentor, mentee: @mentee, status: "completed", scheduled_at: 1.day.ago)
    create_booking(service: service, mentor: @mentor, mentee: @mentee, status: "confirmed")
    create_booking(service: service, mentor: @mentor, mentee: @mentee, status: "cancelled")
    create_booking(service: other_service, mentor: @other, mentee: @mentee, status: "completed")
    get "/api/v1/me/mentorship", headers: auth_headers(@mentor)
    assert_response :ok
    body = response.parsed_body
    assert_equal 1, body.dig("stats", "mentees")
    assert_equal 1, body.dig("stats", "sessions")
    assert_equal 1.0, body.dig("stats", "hours")
    assert_equal 3, body["sessions"].size
    assert_equal 50, body["mentees"].first["progress"]
    assert_equal "Nakasero", body["mentees"].first["school"]
    refute_includes response.body, "Private biography"
    refute_includes response.body, "Private learning goal"
    assert_equal [service.id], body["programmes"].map { |programme| programme["id"] }
  end

  test "goals persist and updates are scoped to owner" do
    post "/api/v1/me/mentorship/goals", headers: auth_headers(@mentor), params: { goal: { title: "Guide five learners", user_id: @other.id } }, as: :json
    assert_response :created
    goal_id = response.parsed_body["id"]
    assert_equal @mentor.id, MentorGoal.find(goal_id).user_id
    patch "/api/v1/me/mentorship/goals/#{goal_id}", headers: auth_headers(@other), params: { goal: { completed: true } }, as: :json
    assert_response :not_found
    patch "/api/v1/me/mentorship/goals/#{goal_id}", headers: auth_headers(@mentor), params: { goal: { completed: true } }, as: :json
    assert_response :ok
    get "/api/v1/me/mentorship", headers: auth_headers(@mentor)
    assert_equal 1, response.parsed_body.dig("stats", "completed_goals")
    assert_equal 0, response.parsed_body.dig("stats", "active_goals")
  end

  test "goals reject blank and oversized titles" do
    [" ", "a" * 201].each do |title|
      post "/api/v1/me/mentorship/goals", headers: auth_headers(@mentor), params: { goal: { title: title } }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "resource library validates links and enforces ownership" do
    post "/api/v1/me/mentorship/resources", headers: auth_headers(@mentor), params: { resource: { title: "Unsafe", url: "javascript:alert(1)" } }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/me/mentorship/resources", headers: auth_headers(@mentor), params: { resource: { title: "Learning guide", url: "https://example.com/guide", user_id: @other.id } }, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    assert_equal @mentor.id, MentorshipResource.find(id).user_id
    get "/api/v1/me/mentorship", headers: auth_headers(@other)
    assert_empty response.parsed_body["resources"]
    delete "/api/v1/me/mentorship/resources/#{id}", headers: auth_headers(@other)
    assert_response :not_found
    delete "/api/v1/me/mentorship/resources/#{id}", headers: auth_headers(@mentor)
    assert_response :no_content
    refute MentorshipResource.exists?(id)
  end

  test "mentor can accept a request using the existing booking API" do
    service = create_service(mentor: @mentor)
    booking = create_booking(service: service, mentor: @mentor, mentee: @mentee)
    patch "/api/v1/bookings/#{booking.id}", headers: auth_headers(@other), params: { status: "confirmed" }, as: :json
    assert_response :not_found
    patch "/api/v1/bookings/#{booking.id}", headers: auth_headers(@mentor), params: { status: "confirmed" }, as: :json
    assert_response :ok
    assert_equal "confirmed", booking.reload.status
    get "/api/v1/me/mentorship", headers: auth_headers(@mentor)
    assert_equal "confirmed", response.parsed_body["sessions"].first["status"]
  end
end
