require "test_helper"

class Api::V1::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @mentor = create_mentor(email: "mentor@example.com", full_name: "Alex Morgan")
    @other_mentor = create_mentor(email: "other@example.com", full_name: "Sarah Chen")
    @mentee = create_mentee(email: "mentee@example.com")
    @category = Category.find_or_create_by!(name: "Software Development") { |record| record.slug = "software-development" }
    @service = create_service(mentor: @mentor, category: @category, title: "React Mentorship", price: 120)
    @other_service = create_service(mentor: @other_mentor, category: @category, title: "Product Coaching", price: 180)
  end

  test "index is public and returns the service envelope" do
    get "/api/v1/services"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["services"].length
    assert_equal 1, body.dig("meta", "page")
    service = body["services"].find { |item| item["id"] == @service.id }
    assert_equal "React Mentorship", service["title"]
    assert_equal 120.0, service["price"]
    assert_equal "Alex Morgan", service.dig("mentor", "name")
  end

  test "index filters by query, category, mentor and sorts by price" do
    get "/api/v1/services", params: { q: "Mentorship", category_id: @service.category_id, mentor_id: @mentor.id, sort: "price-low" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@service.id], body["services"].map { |item| item["id"] }
  end

  test "index paginates" do
    get "/api/v1/services", params: { page: 1, per_page: 1 }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["services"].length
    assert_equal 2, body.dig("meta", "total")
  end

  test "show returns the service" do
    get "/api/v1/services/#{@service.id}"

    assert_response :ok
    assert_equal @service.id, JSON.parse(response.body)["id"]
  end

  test "show returns 404 for a missing service" do
    get "/api/v1/services/999999"

    assert_response :not_found
    assert_equal "Service not found", JSON.parse(response.body)["detail"]
  end

  test "create returns 201 for a mentor" do
    post "/api/v1/services",
         params: { title: "Advanced TypeScript", description: "Deep dive into TypeScript generics.", category_id: @category.id, price: 130, duration: 60, tags: ["TypeScript"] },
         headers: auth_headers(@mentor), as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Advanced TypeScript", body["title"]
    assert_equal @mentor.id, body["mentorId"]
  end

  test "create returns 403 for a mentee" do
    post "/api/v1/services",
         params: { title: "Nope", description: "Nope nope nope.", category_id: @category.id, price: 10, duration: 30 },
         headers: auth_headers(@mentee), as: :json

    assert_response :forbidden
  end

  test "create returns 401 without a token" do
    post "/api/v1/services", params: { title: "Nope" }, as: :json

    assert_response :unauthorized
  end

  test "create returns 422 for invalid attributes" do
    post "/api/v1/services",
         params: { title: "", description: "", category_id: @category.id, price: -1, duration: 0 },
         headers: auth_headers(@mentor), as: :json

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["detail"].any?
  end

  test "update returns 200 for the owning mentor" do
    patch "/api/v1/services/#{@service.id}",
          params: { title: "React Architecture Mentorship" },
          headers: auth_headers(@mentor), as: :json

    assert_response :ok
    assert_equal "React Architecture Mentorship", JSON.parse(response.body)["title"]
  end

  test "update returns 403 for another mentor" do
    patch "/api/v1/services/#{@service.id}",
          params: { title: "Hijacked" },
          headers: auth_headers(@other_mentor), as: :json

    assert_response :forbidden
  end

  test "destroy soft-deletes the owning mentor's service" do
    delete "/api/v1/services/#{@service.id}", headers: auth_headers(@mentor)

    assert_response :ok
    assert_not @service.reload.is_active
  end

  test "destroy returns 403 for another mentor" do
    delete "/api/v1/services/#{@service.id}", headers: auth_headers(@other_mentor)

    assert_response :forbidden
  end
end
