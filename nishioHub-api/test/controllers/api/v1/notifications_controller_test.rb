require "test_helper"

class Api::V1::NotificationsControllerTest < ActionDispatch::IntegrationTest
  def person(email = "notifications@example.com", role = "mentee")
    User.create!(full_name: "Notification Learner", email: email, password: "secret123", role: create_role(role),
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}")
  end

  def alert(user, **attributes)
    user.notifications.create!({ title: "Platform Update", message: "Your learning record is available." }.merge(attributes))
  end

  test "every notification and preference endpoint requires authentication" do
    get "/api/v1/notifications"
    assert_response :unauthorized
    get "/api/v1/me/notifications"
    assert_response :unauthorized
    post "/api/v1/notifications", params: { title: "Test", message: "Test" }
    assert_response :unauthorized
    patch "/api/v1/notifications/read-all"
    assert_response :unauthorized
    patch "/api/v1/me/notification_preferences", params: { preferences: { learning: false } }, as: :json
    assert_response :unauthorized
  end

  test "feeds do not expose other users or unassigned legacy rows" do
    user = person
    other = person("other-notifications@example.com")
    own = alert(user, title: "My alert")
    alert(other, title: "Private other alert")
    Notification.insert_all!([{ title: "Legacy global alert", message: "Unassigned", user_id: nil }])
    get "/api/v1/me/notifications", headers: auth_headers(user)
    assert_response :ok
    assert_equal [own.id], response.parsed_body["notifications"].map { |item| item["id"] }
    assert_equal 1, response.parsed_body.dig("counts", "all")
    refute_includes response.body, "Private other alert"
    refute_includes response.body, "Legacy global alert"
    get "/api/v1/notifications", headers: auth_headers(user)
    assert_equal [own.id], response.parsed_body.map { |item| item["id"] }
  end

  test "read updates and mark all read are scoped to owner" do
    user = person
    other = person("other-read@example.com")
    own = alert(user)
    private_alert = alert(other)
    patch "/api/v1/notifications/#{private_alert.id}", headers: auth_headers(user), params: { notification: { read: true } }, as: :json
    assert_response :not_found
    patch "/api/v1/notifications/#{own.id}", headers: auth_headers(user), params: { notification: { read: true, user_id: other.id } }, as: :json
    assert_response :ok
    assert own.reload.read
    assert_equal user.id, own.user_id
    patch "/api/v1/notifications/#{own.id}", headers: auth_headers(user), params: { notification: { read: false } }, as: :json
    assert_response :ok
    patch "/api/v1/notifications/read-all", headers: auth_headers(user)
    assert_response :ok
    assert own.reload.read
    refute private_alert.reload.read
    get "/api/v1/notifications/unread-count", headers: auth_headers(user)
    assert_equal 0, response.parsed_body["unread"]
  end

  test "server search category filters and pagination retain accurate totals" do
    user = person
    31.times { |index| alert(user, title: "Learning notice #{index}", category: "learning", topic: "learning", icon: "book") }
    alert(user, title: "Mentorship notice", category: "mentorship", topic: "mentorship", read: true)
    get "/api/v1/me/notifications", headers: auth_headers(user), params: { category: "learning" }
    assert_equal 30, response.parsed_body["notifications"].size
    assert_equal 31, response.parsed_body.dig("meta", "total")
    assert_equal 32, response.parsed_body.dig("counts", "all")
    get "/api/v1/me/notifications", headers: auth_headers(user), params: { category: "learning", page: 2 }
    assert_equal 1, response.parsed_body["notifications"].size
    get "/api/v1/me/notifications", headers: auth_headers(user), params: { q: "notice 30", unread: true }
    assert_equal 1, response.parsed_body["notifications"].size
    assert_equal "Learning notice 30", response.parsed_body["notifications"].first["title"]
  end

  test "preferences persist per user and suppress matching future alerts" do
    user = person
    other = person("other-preferences@example.com")
    existing = alert(user)
    patch "/api/v1/me/notification_preferences", headers: auth_headers(user), params: { preferences: { learning: false, user_id: other.id } }, as: :json
    assert_response :ok
    assert_equal false, response.parsed_body["learning"]
    assert_nil other.reload.notification_preference
    assert Notification.exists?(existing.id)
    args = { user: user, title: "Course alert", message: "You completed a course.", category: "learning", icon: "book", href: "/learning-area" }
    assert_nil Notification.deliver(**args, topic: "learning", source_key: "muted-course")
    assert Notification.deliver(**args, topic: "goals", source_key: "unmuted-goal")
    get "/api/v1/me/notification_preferences", headers: auth_headers(user)
    assert_equal false, response.parsed_body["learning"]
  end

  test "course and goal updates generate real notifications without duplicate completions" do
    user = person
    enrollment = user.learning_enrollments.create!(course_key: "programming")
    assert_empty user.notifications
    keys = LearningCatalog.find("programming")["lessons"].map { |lesson| lesson["id"] }
    enrollment.update!(completed_lesson_ids: keys)
    enrollment.update!(completed_lesson_ids: keys)
    assert_equal 1, user.notifications.where(title: "Course Completed!").count
    goal = user.mentee_goals.create!(title: "Improve computer skills")
    goal.update!(progress: 75)
    notice = user.notifications.find_by!(title: "Goal Progress Update")
    assert_includes notice.message, "75%"
    assert_equal "/my-goals", notice.href
  end

  test "booking reminders and badge discovery are deduplicated" do
    user = person
    mentor = person("mentor-notification@example.com", "mentor")
    service = create_service(mentor: mentor)
    booking = create_booking(service: service, mentor: mentor, mentee: user, status: "confirmed", scheduled_at: 2.hours.from_now)
    assert user.notifications.exists?(title: "Mentorship Session Confirmed")
    assert mentor.notifications.exists?(title: "Mentorship Session Confirmed")
    2.times { get "/api/v1/me/notifications", headers: auth_headers(user) }
    assert_equal 1, user.notifications.where(title: "Mentorship Session Reminder").count
    booking.update!(status: "completed")
    2.times { get "/api/v1/me/notifications", headers: auth_headers(user) }
    assert_equal 1, user.notifications.where(source_key: "badge-first-session").count
  end

  test "event reminders respect registration settings and notification ownership" do
    user = person
    owner = person("event-notification-owner@example.com")
    event = owner.organized_events.create!(title: "STEM Challenge", description: "Build something", category: "challenge", starts_at: 10.minutes.from_now, ends_at: 2.hours.from_now, location: "School")
    registration = event.event_registrations.create!(user: user, reminder_minutes: 15)
    assert user.notifications.exists?(title: "Event Registration Confirmed")
    2.times { get "/api/v1/notifications/unread-count", headers: auth_headers(user) }
    assert_equal 1, user.notifications.where(title: "Upcoming Event: STEM Challenge").count
    registration.update!(status: "cancelled")
    another = owner.organized_events.create!(title: "No Reminder", description: "An event", category: "talk", starts_at: 5.minutes.from_now, ends_at: 1.hour.from_now, location: "Online")
    another.event_registrations.create!(user: user, reminder_minutes: 0)
    get "/api/v1/me/notifications", headers: auth_headers(user)
    refute user.notifications.exists?(title: "Upcoming Event: No Reminder")
    assert_empty owner.notifications
  end

  test "notification creation ignores a supplied recipient and rejects unsafe values" do
    user = person
    other = person("spoof-notifications@example.com")
    post "/api/v1/notifications", headers: auth_headers(user), params: { title: "My note", message: "Private note", user_id: other.id }, as: :json
    assert_response :created
    assert_equal user.id, Notification.find(response.parsed_body["id"]).user_id
    assert_empty other.notifications
    assert_raises(ActiveRecord::RecordInvalid) { alert(user, href: "//evil.example.com") }
  end
end
