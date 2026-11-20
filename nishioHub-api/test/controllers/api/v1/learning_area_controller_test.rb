require "test_helper"

class Api::V1::LearningAreaControllerTest < ActionDispatch::IntegrationTest
  def learner(email = "learning@example.com", role = "mentee")
    User.create!(full_name: "Learning Student", email: email, password: "secret123",
                 phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}",
                 role: create_role(role))
  end

  test "learning endpoints require an authenticated mentee" do
    get "/api/v1/me/learning_area"
    assert_response :unauthorized
    post "/api/v1/me/learning_area/programming/enroll"
    assert_response :unauthorized
    mentor = learner("mentor-learning@example.com", "mentor")
    get "/api/v1/me/learning_area", headers: auth_headers(mentor)
    assert_response :forbidden
    post "/api/v1/me/learning_area/programming/enroll", headers: auth_headers(mentor)
    assert_response :forbidden
  end

  test "catalogue has content and accurate empty progress" do
    get "/api/v1/me/learning_area", headers: auth_headers(learner)
    assert_response :ok
    body = response.parsed_body
    assert_equal 7, body["categories"].size
    assert_equal 8, body["courses"].size
    assert_equal 4, body["courses"].count { |course| course["featured"] }
    assert body["courses"].all? { |course| course["lessons"].all? { |lesson| lesson["content"].present? && lesson["practice"].present? } }
    assert_equal({ "enrolled" => 0, "completed" => 0, "percent" => 0, "hours" => 0.0, "streak" => 0 }, body["progress"])
  end

  test "enrolment is idempotent and lesson completion is saved once" do
    student = learner
    2.times do
      post "/api/v1/me/learning_area/programming/enroll", headers: auth_headers(student)
      assert_response :ok
    end
    assert_equal 1, student.learning_enrollments.count
    2.times do
      post "/api/v1/me/learning_area/programming/lessons/programming-1/complete", headers: auth_headers(student)
      assert_response :ok
    end
    get "/api/v1/me/learning_area", headers: auth_headers(student)
    body = response.parsed_body
    assert_equal 25, body.dig("progress", "percent")
    assert_equal 0.5, body.dig("progress", "hours")
    assert_equal 1, body.dig("progress", "streak")
    assert_equal ["programming-1"], body["courses"].find { |course| course["id"] == "programming" }["completed_lesson_ids"]
    %w[programming-2 programming-3 programming-4].each do |id|
      post "/api/v1/me/learning_area/programming/lessons/#{id}/complete", headers: auth_headers(student)
      assert_response :ok
    end
    get "/api/v1/me/learning_area", headers: auth_headers(student)
    assert_equal 100, response.parsed_body.dig("progress", "percent")
    assert_equal 1, response.parsed_body.dig("progress", "completed")
    assert_equal 2.0, response.parsed_body.dig("progress", "hours")
  end

  test "learners cannot complete another learner enrolment" do
    owner = learner
    other = learner("other-learning@example.com")
    owner.learning_enrollments.create!(course_key: "programming")
    post "/api/v1/me/learning_area/programming/lessons/programming-1/complete", headers: auth_headers(other)
    assert_response :not_found
    assert_empty owner.learning_enrollments.first.completed_lesson_ids
    get "/api/v1/me/learning_area", headers: auth_headers(other)
    assert_equal 0, response.parsed_body.dig("progress", "enrolled")
  end

  test "invalid courses and lessons cannot change progress" do
    student = learner
    post "/api/v1/me/learning_area/unknown/enroll", headers: auth_headers(student)
    assert_response :not_found
    student.learning_enrollments.create!(course_key: "programming")
    post "/api/v1/me/learning_area/programming/lessons/robotics-1/complete", headers: auth_headers(student)
    assert_response :not_found
    assert_empty student.learning_enrollments.first.completed_lesson_ids
  end

  test "streak uses consecutive days and expires after a gap" do
    student = learner
    enrollment = student.learning_enrollments.create!(course_key: "programming", activity_dates: [Date.yesterday.iso8601, 2.days.ago.to_date.iso8601])
    get "/api/v1/me/learning_area", headers: auth_headers(student)
    assert_equal 2, response.parsed_body.dig("progress", "streak")
    enrollment.update!(activity_dates: [2.days.ago.to_date.iso8601])
    get "/api/v1/me/learning_area", headers: auth_headers(student)
    assert_equal 0, response.parsed_body.dig("progress", "streak")
  end
end
