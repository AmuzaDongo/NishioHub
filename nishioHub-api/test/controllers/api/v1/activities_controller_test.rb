require "test_helper"

class Api::V1::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  def learner(email = "activities@example.com", role = "mentee")
    User.create!(full_name: "Activity Learner", email: email, password: "secret123",
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}", role: create_role(role))
  end

  test "activity feed requires a signed in mentee" do
    get "/api/v1/me/activities"
    assert_response :unauthorized
    get "/api/v1/me/activities", headers: auth_headers(learner("activity-mentor@example.com", "mentor"))
    assert_response :forbidden
  end

  test "new learners have empty activity feeds and zero totals" do
    get "/api/v1/me/activities", headers: auth_headers(learner)
    assert_response :ok
    assert_empty response.parsed_body["activities"]
    assert_equal({ "total" => 0, "completed" => 0, "in_progress" => 0, "upcoming" => 0 }, response.parsed_body["stats"])
  end

  test "lesson completion is timestamped and not duplicated on retries" do
    student = learner
    post "/api/v1/me/learning_area/programming/enroll", headers: auth_headers(student)
    assert_response :ok
    travel_to Time.zone.local(2026, 11, 6, 13, 30) do
      2.times do
        post "/api/v1/me/learning_area/programming/lessons/programming-1/complete", headers: auth_headers(student)
        assert_response :ok
      end
      assert_equal 1, student.learning_enrollments.first.learning_lesson_completions.count
      get "/api/v1/me/activities", headers: auth_headers(student)
      body = response.parsed_body
      lesson = body["activities"].find { |item| item["id"].start_with?("lesson-") }
      assert_equal "Completed: Computer Basics", lesson["title"]
      assert_equal Time.current.iso8601, lesson["occurred_at"]
      assert_includes lesson["href"], "lesson=programming-1"
      assert_equal 1, body.dig("stats", "completed")
      assert_equal 1, body.dig("stats", "in_progress")
      assert_equal 2, body.dig("stats", "total")
    end
  end

  test "legacy enrolments show their saved snapshot without invented lesson dates" do
    student = learner
    enrollment = student.learning_enrollments.create!(course_key: "programming")
    enrollment.update_columns(completed_lesson_ids: ["programming-1"])
    get "/api/v1/me/activities", headers: auth_headers(student)
    entries = response.parsed_body["activities"]
    assert_equal 1, entries.size
    assert_equal "in_progress", entries.first["status"]
    assert_includes entries.first["description"], "1 of 4"
    assert entries.none? { |entry| entry["id"].start_with?("lesson-") }
  end

  test "bookings reflect actual status and activities stay private" do
    student = learner
    other = learner("other-activities@example.com")
    mentor = learner("mentor-activities@example.com", "mentor")
    service = create_service(mentor: mentor)
    future = create_booking(service: service, mentor: mentor, mentee: student, status: "confirmed")
    past = create_booking(service: service, mentor: mentor, mentee: student, status: "completed", scheduled_at: 2.days.ago)
    cancelled = create_booking(service: service, mentor: mentor, mentee: student, status: "cancelled")
    create_booking(service: service, mentor: mentor, mentee: other, status: "confirmed")
    other.mentee_goals.create!(title: "Private other goal")
    other.learning_enrollments.create!(course_key: "robotics")
    student.mentee_goals.create!(title: "My learning goal", progress: 40)
    get "/api/v1/me/activities", headers: auth_headers(student)
    body = response.parsed_body
    assert_equal 4, body["activities"].size
    assert_equal "upcoming", body["activities"].find { |entry| entry["id"] == "booking-#{future.id}" }["status"]
    assert_equal "completed", body["activities"].find { |entry| entry["id"] == "booking-#{past.id}" }["status"]
    assert_equal "cancelled", body["activities"].find { |entry| entry["id"] == "booking-#{cancelled.id}" }["status"]
    assert_equal 1, body.dig("stats", "upcoming")
    refute_includes response.body, "Private other goal"
    refute_includes response.body, "Robotics for Beginners"
    assert body["activities"].all? { |entry| entry["category"].in?(%w[learning mentorship]) }
  end
end
