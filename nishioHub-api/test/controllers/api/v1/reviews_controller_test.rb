require "test_helper"

class Api::V1::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mentor = create_mentor(email: "mentor@example.com", full_name: "Alex Morgan")
    @mentee = create_mentee(email: "mentee@example.com", full_name: "Carlos Rodriguez")
    @category = Category.find_or_create_by!(name: "Software Development") { |record| record.slug = "software-development" }
    @service = create_service(mentor: @mentor, category: @category, title: "React Mentorship", price: 120)
    @booking = create_booking(service: @service, mentee: @mentee, mentor: @mentor, status: "completed")
    @review = Review.create!(booking: @booking, service: @service, mentor: @mentor, mentee: @mentee, rating: 5, comment: "Excellent session.")
  end

  test "index is public and returns reviews" do
    get "/api/v1/reviews"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["reviews"].length
    assert_equal 5, body["reviews"].first["rating"]
    assert_equal "Carlos Rodriguez", body["reviews"].first.dig("mentee", "name")
  end

  test "index filters by mentor and service" do
    get "/api/v1/reviews", params: { mentor_id: @mentor.id, service_id: @service.id }

    assert_response :ok
    assert_equal 1, JSON.parse(response.body)["reviews"].length
  end
end
