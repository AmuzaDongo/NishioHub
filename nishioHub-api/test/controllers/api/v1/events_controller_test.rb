require "test_helper"

class Api::V1::EventsControllerTest < ActionDispatch::IntegrationTest
  def participant(email = "events@example.com", role = "mentee")
    User.create!(full_name: "Event Learner", email: email, password: "secret123", role: create_role(role),
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}")
  end

  def event_for(organizer, **attributes)
    Event.create!({ organizer: organizer, title: "Software Career Talk", description: "Meet an engineer and explore careers.",
      category: "talk", starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour,
      location: "Online", meeting_url: "https://example.com/meeting" }.merge(attributes))
  end

  test "events require authentication" do
    get "/api/v1/events"
    assert_response :unauthorized
    post "/api/v1/events/1/registration"
    assert_response :unauthorized
    post "/api/v1/events/suggestions"
    assert_response :unauthorized
  end

  test "registrations are idempotent capacity limited and can be cancelled then renewed" do
    owner = participant("owner-events@example.com")
    learner = participant
    other = participant("other-events@example.com")
    event = event_for(owner, capacity: 1)
    2.times do
      post "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner)
      assert_response :ok
    end
    assert_equal 1, event.event_registrations.count
    assert_equal 0, response.parsed_body["available_places"]
    post "/api/v1/events/#{event.id}/registration", headers: auth_headers(other)
    assert_response :unprocessable_entity
    delete "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner)
    assert_response :no_content
    post "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner)
    assert_response :ok
    assert_equal 1, event.event_registrations.count
    get "/api/v1/events", headers: auth_headers(learner)
    assert_equal 1, response.parsed_body.dig("summary", "registered")
    assert_equal 1, response.parsed_body.dig("summary", "upcoming")
  end

  test "registration and organizer data are scoped and meeting links require registration" do
    owner = participant("owner-private-events@example.com")
    learner = participant
    other = participant("other-private-events@example.com")
    event = event_for(owner)
    event.event_registrations.create!(user: learner)
    get "/api/v1/events/#{event.id}", headers: auth_headers(other)
    assert_nil response.parsed_body["meeting_url"]
    assert_nil response.parsed_body["registration"]
    get "/api/v1/events/#{event.id}", headers: auth_headers(learner)
    assert_equal "https://example.com/meeting", response.parsed_body["meeting_url"]
    get "/api/v1/events/#{event.id}/attendees", headers: auth_headers(other)
    assert_response :forbidden
    get "/api/v1/events/#{event.id}/attendees", headers: auth_headers(owner)
    assert_response :ok
    assert_equal 1, response.parsed_body.size
    get "/api/v1/events/#{event.id}/calendar", headers: auth_headers(other)
    assert_response :not_found
    patch "/api/v1/events/#{event.id}/registration", headers: auth_headers(other), params: { registration: { reminder_minutes: 30 } }, as: :json
    assert_response :not_found
  end

  test "event creation validates dates and assigns the authenticated organizer" do
    owner = participant
    other = participant("spoofed-owner@example.com")
    payload = { title: "Coding Workshop", description: "Learn to build a page.", category: "workshop", starts_at: 3.days.from_now.iso8601,
      ends_at: (3.days.from_now + 1.hour).iso8601, location: "School hall", organizer_id: other.id }
    post "/api/v1/events", headers: auth_headers(owner), params: { event: payload }, as: :json
    assert_response :created
    assert_equal owner.id, response.parsed_body.dig("organizer", "id")
    post "/api/v1/events", headers: auth_headers(owner), params: { event: payload.merge(ends_at: 1.day.ago.iso8601) }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/events", headers: auth_headers(owner), params: { event: payload.merge(starts_at: 1.day.ago.iso8601) }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/events", headers: auth_headers(owner), params: { event: payload.merge(meeting_url: "javascript:alert(1)") }, as: :json
    assert_response :unprocessable_entity
  end

  test "calendar downloads contain the saved reminder and safe folded text" do
    learner = participant
    event = event_for(participant("calendar-owner@example.com"), title: "Coding, Practice; Learn", description: "Useful\\notes\nSecond line " + "é" * 100)
    registration = event.event_registrations.create!(user: learner)
    patch "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner), params: { registration: { reminder_minutes: 60, user_id: event.organizer_id, attended_at: Time.current.iso8601 } }, as: :json
    assert_response :ok
    assert_nil registration.reload.attended_at
    assert_equal learner.id, registration.user_id
    get "/api/v1/events/#{event.id}/calendar", headers: auth_headers(learner)
    assert_response :ok
    assert_equal "text/calendar", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.body, "TRIGGER:-PT60M"
    assert_includes response.body, "Coding\\, Practice\\; Learn"
    assert_includes response.body, "Useful\\\\notes\\nSecond line"
    assert_includes response.body, "URL:https://example.com/meeting"
    assert response.body.split("\r\n").all? { |line| line.bytesize <= 75 }
    assert_equal 1, response.body.scan("BEGIN:VEVENT").size
    patch "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner), params: { registration: { reminder_minutes: 5 } }, as: :json
    assert_response :unprocessable_entity
  end

  test "only organizers record attendance after event starts and attendance unlocks achievements" do
    learner = participant
    owner = participant("attend-owner@example.com")
    event = event_for(owner)
    registration = event.event_registrations.create!(user: learner)
    patch "/api/v1/events/#{event.id}/attendees/#{registration.id}", headers: auth_headers(learner), params: { registration: { attended: true } }, as: :json
    assert_response :forbidden
    patch "/api/v1/events/#{event.id}/attendees/#{registration.id}", headers: auth_headers(owner), params: { registration: { attended: true } }, as: :json
    assert_response :unprocessable_entity
    travel_to event.starts_at + 5.minutes do
      patch "/api/v1/events/#{event.id}/attendees/#{registration.id}", headers: auth_headers(owner), params: { registration: { attended: true } }, as: :json
      assert_response :ok
      assert registration.reload.attended_at
      get "/api/v1/events", headers: auth_headers(learner)
      assert_equal 1, response.parsed_body.dig("summary", "attended")
      get "/api/v1/me/achievements", headers: auth_headers(learner)
      assert response.parsed_body["badges"].find { |badge| badge["id"] == "event-participant" }["earned"]
      get "/api/v1/me/activities", headers: auth_headers(learner)
      assert_equal "events", response.parsed_body["activities"].first["category"]
      assert_equal "completed", response.parsed_body["activities"].first["status"]
      delete "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner)
      assert_response :unprocessable_entity
    end
  end

  test "ended events cannot be registered and suggestions are private" do
    learner = participant
    other = participant("suggestion-other@example.com")
    event = event_for(other, starts_at: 2.days.ago, ends_at: 1.day.ago)
    post "/api/v1/events/#{event.id}/registration", headers: auth_headers(learner)
    assert_response :unprocessable_entity
    post "/api/v1/events/suggestions", headers: auth_headers(learner), params: { suggestion: { title: "Art workshop", description: "Practice creative design", category: "workshop", user_id: other.id } }, as: :json
    assert_response :created
    get "/api/v1/events", headers: auth_headers(other)
    assert_empty response.parsed_body["suggestions"]
    get "/api/v1/events", headers: auth_headers(learner)
    assert_equal "Art workshop", response.parsed_body["suggestions"].first["title"]
    refute response.parsed_body["events"].any? { |item| item["id"] == event.id }
  end
end
