require "test_helper"
require "csv"

class Api::V1::AchievementsControllerTest < ActionDispatch::IntegrationTest
  def learner(email = "achievements@example.com", role = "mentee", name = "Achievement Learner")
    User.create!(full_name: name, email: email, password: "secret123",
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}", role: create_role(role))
  end

  def finish_course(user, key = "programming")
    user.learning_enrollments.create!(course_key: key, completed_lesson_ids: LearningCatalog.find(key)["lessons"].map { |lesson| lesson["id"] })
  end

  test "achievement and download endpoints require authenticated mentees" do
    get "/api/v1/me/achievements"
    assert_response :unauthorized
    get "/api/v1/me/achievements/record"
    assert_response :unauthorized
    mentor = learner("achievement-mentor@example.com", "mentor")
    get "/api/v1/me/achievements", headers: auth_headers(mentor)
    assert_response :forbidden
    get "/api/v1/me/achievements/certificates/unknown", headers: auth_headers(mentor)
    assert_response :forbidden
  end

  test "new learners have honest zero totals and locked badges" do
    get "/api/v1/me/achievements", headers: auth_headers(learner)
    assert_response :ok
    body = response.parsed_body
    assert_equal({ "courses" => 0, "badges" => 0, "certificates" => 0, "progress" => 0 }, body["summary"])
    assert_empty body["certificates"]
    assert_empty body["achievements"]
    assert body["badges"].none? { |badge| badge["earned"] }
  end

  test "partial courses do not issue certificates and repeated completion is stable" do
    user = learner
    enrollment = user.learning_enrollments.create!(course_key: "programming", completed_lesson_ids: ["programming-1"])
    assert_nil enrollment.learning_certificate
    get "/api/v1/me/achievements", headers: auth_headers(user)
    assert_equal 25, response.parsed_body.dig("summary", "progress")
    assert_empty response.parsed_body["certificates"]
    enrollment.update!(completed_lesson_ids: LearningCatalog.find("programming")["lessons"].map { |lesson| lesson["id"] })
    certificate = enrollment.learning_certificate
    assert certificate.persisted?
    issued_at = certificate.issued_at
    2.times do
      post "/api/v1/me/learning_area/programming/lessons/programming-1/complete", headers: auth_headers(user)
      assert_response :ok
    end
    assert_equal 1, LearningCertificate.where(learning_enrollment: enrollment).count
    assert_equal issued_at, certificate.reload.issued_at
    get "/api/v1/me/achievements", headers: auth_headers(user)
    assert_equal 1, response.parsed_body.dig("summary", "certificates")
    assert_equal certificate.identifier, response.parsed_body["certificates"].first["id"]
  end

  test "badges and summary use real course goal and mentorship accomplishments" do
    user = learner
    %w[programming robotics innovation].each { |key| finish_course(user, key) }
    goal = user.mentee_goals.create!(title: "Complete my learning goal", progress: 100)
    goal.goal_milestones.create!(title: "Finish project", completed: true)
    mentor = learner("mentor-badge@example.com", "mentor")
    service = create_service(mentor: mentor)
    create_booking(service: service, mentor: mentor, mentee: user, status: "completed")
    get "/api/v1/me/achievements", headers: auth_headers(user)
    assert_response :ok
    body = response.parsed_body
    assert_equal 3, body.dig("summary", "courses")
    assert_equal 3, body.dig("summary", "certificates")
    assert_equal 5, body.dig("summary", "badges")
    assert_equal 100, body.dig("summary", "progress")
    earned = body["badges"].select { |badge| badge["earned"] }.map { |badge| badge["id"] }
    assert_includes earned, "active-learner"
    assert_includes earned, "goal-setter"
    assert_includes earned, "rising-innovator"
    refute_includes earned, "event-participant"
    assert_equal "Finish project", body["milestones"].first["title"]
  end

  test "certificate SVG safely escapes names and is private to owner" do
    user = learner("xml@example.com", "mentee", "<script>Example & Learner</script>")
    other = learner("other-certificate@example.com")
    certificate = finish_course(user).learning_certificate
    get "/api/v1/me/achievements/certificates/#{certificate.identifier}", headers: auth_headers(other)
    assert_response :not_found
    get "/api/v1/me/achievements/certificates/#{certificate.identifier}", headers: auth_headers(user)
    assert_response :ok
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.body, "&lt;script&gt;Example &amp; Learner&lt;/script&gt;"
    refute_includes response.body, "<script>"
    get "/api/v1/me/achievements", headers: auth_headers(other)
    assert_empty response.parsed_body["certificates"]
    assert_empty response.parsed_body["achievements"]
  end

  test "CSV record is downloadable scoped and protects spreadsheet cells" do
    user = learner("csv@example.com", "mentee", "=HYPERLINK(\"unsafe\")")
    other = learner("other-csv@example.com")
    other.mentee_goals.create!(title: "Other private goal", progress: 100)
    finish_course(user)
    get "/api/v1/me/achievements/record", headers: auth_headers(user)
    assert_response :ok
    assert_equal "text/csv", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    rows = CSV.parse(response.body)
    assert rows.size > 1
    assert_equal "'=HYPERLINK(\"unsafe\")", rows[1][0]
    refute_includes response.body, "Other private goal"
  end
end
