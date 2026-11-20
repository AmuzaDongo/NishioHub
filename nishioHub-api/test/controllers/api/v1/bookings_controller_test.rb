require "test_helper"

class Api::V1::BookingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mentor = create_mentor(email: "mentor@example.com", full_name: "Alex Morgan")
    @other_mentor = create_mentor(email: "other@example.com", full_name: "Sarah Chen")
    @mentee = create_mentee(email: "mentee@example.com", full_name: "Carlos Rodriguez")
    @other_mentee = create_mentee(email: "other-mentee@example.com", full_name: "Emma Johnson")
    @category = Category.find_or_create_by!(name: "Software Development") { |record| record.slug = "software-development" }
    @service = create_service(mentor: @mentor, category: @category, title: "React Mentorship", price: 120)
    @booking = create_booking(service: @service, mentee: @mentee, mentor: @mentor, status: "pending")
  end

  test "index returns 401 without a token" do
    get "/api/v1/bookings"

    assert_response :unauthorized
  end

  test "index returns only the current user's bookings" do
    create_booking(service: @service, mentee: @other_mentee, mentor: @mentor, status: "confirmed")

    get "/api/v1/bookings", headers: auth_headers(@mentee)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@booking.id], body["bookings"].map { |item| item["id"] }
  end

  test "index filters by role and status" do
    get "/api/v1/bookings", params: { role: "mentor", status: "pending" }, headers: auth_headers(@mentor)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@booking.id], body["bookings"].map { |item| item["id"] }
  end

  test "show returns the booking for a participant" do
    get "/api/v1/bookings/#{@booking.id}", headers: auth_headers(@mentee)

    assert_response :ok
    assert_equal @booking.id, JSON.parse(response.body)["id"]
  end

  test "show returns 404 for a non-participant" do
    get "/api/v1/bookings/#{@booking.id}", headers: auth_headers(@other_mentee)

    assert_response :not_found
  end

  test "create returns 201 for a mentee" do
    post "/api/v1/bookings",
         params: { service_id: @service.id, scheduled_at: 3.days.from_now.change(hour: 15) },
         headers: auth_headers(@mentee), as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "pending", body["status"]
    assert_equal @service.id, body["serviceId"]
    assert_equal @mentor.id, body["mentorId"]
  end

  test "create returns 403 for a mentor" do
    post "/api/v1/bookings",
         params: { service_id: @service.id, scheduled_at: 3.days.from_now.change(hour: 15) },
         headers: auth_headers(@mentor), as: :json

    assert_response :forbidden
  end

  test "create returns 404 for a missing service" do
    post "/api/v1/bookings",
         params: { service_id: 999999, scheduled_at: 3.days.from_now.change(hour: 15) },
         headers: auth_headers(@mentee), as: :json

    assert_response :not_found
  end

  test "create returns 422 for a past scheduled_at" do
    post "/api/v1/bookings",
         params: { service_id: @service.id, scheduled_at: 2.days.ago },
         headers: auth_headers(@mentee), as: :json

    assert_response :unprocessable_entity
  end

  test "mentor can confirm a pending booking" do
    patch "/api/v1/bookings/#{@booking.id}", params: { status: "confirmed" }, headers: auth_headers(@mentor), as: :json

    assert_response :ok
    assert_equal "confirmed", @booking.reload.status
  end

  test "mentee cannot confirm a pending booking" do
    patch "/api/v1/bookings/#{@booking.id}", params: { status: "confirmed" }, headers: auth_headers(@mentee), as: :json

    assert_response :forbidden
  end

  test "mentee can cancel a pending booking" do
    patch "/api/v1/bookings/#{@booking.id}", params: { status: "cancelled" }, headers: auth_headers(@mentee), as: :json

    assert_response :ok
    assert_equal "cancelled", @booking.reload.status
  end

  test "mentor can complete a confirmed booking" do
    @booking.update!(status: "confirmed")

    patch "/api/v1/bookings/#{@booking.id}", params: { status: "completed" }, headers: auth_headers(@mentor), as: :json

    assert_response :ok
    assert_equal "completed", @booking.reload.status
  end

  test "invalid status returns 422" do
    patch "/api/v1/bookings/#{@booking.id}", params: { status: "bogus" }, headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
  end

  test "non-participant cannot update a booking" do
    patch "/api/v1/bookings/#{@booking.id}", params: { status: "cancelled" }, headers: auth_headers(@other_mentee), as: :json

    assert_response :not_found
  end

  test "mentee can review a completed booking once" do
    @booking.update!(status: "completed")

    post "/api/v1/bookings/#{@booking.id}/review",
         params: { rating: 5, comment: "Excellent session, very practical." },
         headers: auth_headers(@mentee), as: :json

    assert_response :created
    assert_equal 5, JSON.parse(response.body)["rating"]

    post "/api/v1/bookings/#{@booking.id}/review",
         params: { rating: 4, comment: "Second review attempt." },
         headers: auth_headers(@mentee), as: :json

    assert_response :unprocessable_entity
  end

  test "mentor cannot review a booking" do
    @booking.update!(status: "completed")

    post "/api/v1/bookings/#{@booking.id}/review",
         params: { rating: 5, comment: "Mentor review attempt." },
         headers: auth_headers(@mentor), as: :json

    assert_response :forbidden
  end

  test "cannot review a pending booking" do
    post "/api/v1/bookings/#{@booking.id}/review",
         params: { rating: 5, comment: "Too early to review." },
         headers: auth_headers(@mentee), as: :json

    assert_response :unprocessable_entity
  end
end
