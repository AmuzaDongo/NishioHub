require "test_helper"

class Api::V1::MentorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mentor = create_mentor(email: "mentor@example.com", full_name: "Alex Morgan", title: "Senior Engineer", rate: 150, skills: ["React", "Node.js"])
    @other_mentor = create_mentor(email: "other@example.com", full_name: "Sarah Chen", title: "Product Lead", rate: 180, skills: ["Product Strategy"])
    @mentee = create_mentee(email: "mentee@example.com", full_name: "Carlos Rodriguez")
    @category = Category.find_or_create_by!(name: "Software Development") { |record| record.slug = "software-development" }
    @service = create_service(mentor: @mentor, category: @category, title: "React Mentorship", price: 120)
    @slot = @mentor.availability_slots.create!(starts_at: 2.days.from_now.change(hour: 10), ends_at: 2.days.from_now.change(hour: 11))
    @other_slot = @other_mentor.availability_slots.create!(starts_at: 3.days.from_now.change(hour: 10), ends_at: 3.days.from_now.change(hour: 11))
  end

  test "index is public and returns the mentor envelope" do
    get "/api/v1/mentors"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["mentors"].length
    assert_equal 1, body.dig("meta", "page")
    mentor = body["mentors"].find { |item| item["id"] == @mentor.id }
    assert_equal "Alex Morgan", mentor["name"]
    assert_equal ["React", "Node.js"], mentor["skills"]
    assert_equal 150.0, mentor["hourlyRate"]
  end

  test "index filters by query, skill, availability and sorts by rating" do
    get "/api/v1/mentors", params: { q: "Alex", skill: "React", available: "true", sort: "rating" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@mentor.id], body["mentors"].map { |item| item["id"] }
  end

  test "index paginates" do
    get "/api/v1/mentors", params: { page: 1, per_page: 1 }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["mentors"].length
    assert_equal 1, body.dig("meta", "per_page")
    assert_equal 2, body.dig("meta", "total")
  end

  test "show returns the full profile" do
    get "/api/v1/mentors/#{@mentor.id}"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Alex Morgan", body["name"]
    assert_equal "Senior Engineer", body["title"]
    assert_equal ["React", "Node.js"], body["skills"]
    assert_equal 1, body["services"].length
    assert_equal 1, body["availability"].length
  end

  test "show returns 404 for a missing mentor" do
    get "/api/v1/mentors/999999"

    assert_response :not_found
    assert_equal "Mentor not found", JSON.parse(response.body)["detail"]
  end

  test "me returns the mentor self profile" do
    get "/api/v1/mentors/me", headers: auth_headers(@mentor)

    assert_response :ok
    assert_equal @mentor.id, JSON.parse(response.body)["id"]
  end

  test "me returns 403 for a mentee" do
    get "/api/v1/mentors/me", headers: auth_headers(@mentee)

    assert_response :forbidden
    assert_equal "Mentor access required", JSON.parse(response.body)["detail"]
  end

  test "me returns 401 without a token" do
    get "/api/v1/mentors/me"

    assert_response :unauthorized
  end

  test "update_me updates the profile and skills" do
    patch "/api/v1/mentors/me",
          params: { title: "Principal Engineer", accepting_bookings: false, skills: ["React", "Leadership"] },
          headers: auth_headers(@mentor), as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Principal Engineer", body["title"]
    assert_equal false, body["acceptingBookings"]
    assert_equal ["React", "Leadership"], body["skills"]
  end

  test "update_me returns 422 for invalid years of experience" do
    patch "/api/v1/mentors/me",
          params: { years_of_experience: -1 },
          headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["detail"].any?
  end

  test "update_me returns 403 for a mentee" do
    patch "/api/v1/mentors/me", params: { title: "Nope" }, headers: auth_headers(@mentee), as: :json

    assert_response :forbidden
  end

  test "stats returns the mentor dashboard numbers" do
    create_booking(service: @service, mentee: @mentee, mentor: @mentor, status: "completed", payment_status: "completed")

    get "/api/v1/mentors/me/stats", headers: auth_headers(@mentor)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 120.0, body["totalEarnings"]
    assert_equal 1, body["completedSessions"]
    assert_equal 1, body["activeServices"]
    assert_equal 1, body["uniqueMentees"]
  end

  test "availability is public" do
    get "/api/v1/mentors/#{@mentor.id}/availability"

    assert_response :ok
    assert_equal 1, JSON.parse(response.body)["availability"].length
  end

  test "create_availability returns 201 for the owning mentor" do
    post "/api/v1/mentors/me/availability",
         params: { starts_at: 4.days.from_now.change(hour: 9), ends_at: 4.days.from_now.change(hour: 10) },
         headers: auth_headers(@mentor), as: :json

    assert_response :created
    assert_equal @mentor.id, JSON.parse(response.body)["mentorId"]
  end

  test "create_availability returns 422 when ends_at is before starts_at" do
    post "/api/v1/mentors/me/availability",
         params: { starts_at: 4.days.from_now.change(hour: 10), ends_at: 4.days.from_now.change(hour: 9) },
         headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "create_availability returns 403 for a mentee" do
    post "/api/v1/mentors/me/availability",
         params: { starts_at: 4.days.from_now.change(hour: 9), ends_at: 4.days.from_now.change(hour: 10) },
         headers: auth_headers(@mentee), as: :json

    assert_response :forbidden
  end

  test "update_availability updates the owning mentor's slot" do
    patch "/api/v1/mentors/me/availability/#{@slot.id}",
          params: { starts_at: 5.days.from_now.change(hour: 9), ends_at: 5.days.from_now.change(hour: 10) },
          headers: auth_headers(@mentor), as: :json

    assert_response :ok
    assert_equal @slot.id, JSON.parse(response.body)["id"]
  end

  test "update_availability returns 404 for another mentor's slot" do
    patch "/api/v1/mentors/me/availability/#{@other_slot.id}",
          params: { starts_at: 5.days.from_now.change(hour: 9), ends_at: 5.days.from_now.change(hour: 10) },
          headers: auth_headers(@mentor), as: :json

    assert_response :not_found
  end

  test "destroy_availability deletes the owning mentor's slot" do
    delete "/api/v1/mentors/me/availability/#{@slot.id}", headers: auth_headers(@mentor)

    assert_response :ok
    assert_not AvailabilitySlot.exists?(@slot.id)
  end

  test "reviews returns the mentor's reviews" do
    booking = create_booking(service: @service, mentee: @mentee, mentor: @mentor, status: "completed", payment_status: "completed")
    Review.create!(booking: booking, service: @service, mentor: @mentor, mentee: @mentee, rating: 5, comment: "Excellent session.")

    get "/api/v1/mentors/#{@mentor.id}/reviews"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["reviews"].length
    assert_equal 5, body["reviews"].first["rating"]
  end
end
