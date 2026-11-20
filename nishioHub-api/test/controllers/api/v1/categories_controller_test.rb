require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: create_role("admin"), email: "admin@example.com", full_name: "Admin")
    @mentee = create_mentee(email: "mentee@example.com", full_name: "Mentee")
    @mentor = create_mentor(email: "mentor@example.com", full_name: "Mentor")
    @category = Category.create!(name: "Software Development", is_active: true, position: 1)
    @inactive = Category.create!(name: "Career Development", is_active: false, position: 2)
    @service = create_service(mentor: @mentor, category: @category, title: "React Mentorship")
  end

  test "index is public and returns active categories ordered by position" do
    get "/api/v1/categories"

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [@category.id], body.map { |category| category["id"] }
    assert_equal "software-development", body.first["slug"]
    assert_equal 1, body.first["service_count"]
    assert_nil body.first["image_url"]
    assert body.first.key?("image_metadata")
  end

  test "index excludes inactive categories for the public" do
    get "/api/v1/categories"

    assert_response :ok
    names = JSON.parse(response.body).map { |category| category["name"] }
    assert_not_includes names, "Career Development"
  end

  test "index includes inactive categories for an admin" do
    get "/api/v1/categories", params: { include_inactive: "true" }, headers: auth_headers(@admin)

    assert_response :ok
    names = JSON.parse(response.body).map { |category| category["name"] }
    assert_includes names, "Career Development"
  end

  test "index filters by query and parent" do
    child = Category.create!(name: "Frontend", is_active: true, parent: @category, position: 3)

    get "/api/v1/categories", params: { q: "Front", parent_id: @category.id }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [child.id], body.map { |category| category["id"] }
  end

  test "show returns a category by id" do
    get "/api/v1/categories/#{@category.id}"

    assert_response :ok
    assert_equal @category.id, JSON.parse(response.body)["id"]
  end

  test "show returns a category by slug" do
    get "/api/v1/categories/#{@category.slug}"

    assert_response :ok
    assert_equal @category.id, JSON.parse(response.body)["id"]
  end

  test "show_by_slug returns a category" do
    get "/api/v1/categories/by-slug/#{@category.slug}"

    assert_response :ok
    assert_equal @category.id, JSON.parse(response.body)["id"]
  end

  test "show returns 404 for a missing category" do
    get "/api/v1/categories/999999"

    assert_response :not_found
    assert_equal "Category not found", JSON.parse(response.body)["detail"]
  end

  test "show hides an inactive category from the public" do
    get "/api/v1/categories/#{@inactive.id}"

    assert_response :not_found
  end

  test "show allows an admin to see an inactive category" do
    get "/api/v1/categories/#{@inactive.id}", headers: auth_headers(@admin)

    assert_response :ok
    assert_equal false, JSON.parse(response.body)["is_active"]
  end

  test "create returns 201 for an admin and generates a slug" do
    post "/api/v1/categories",
         params: { category: { name: "Data Science", description: "Data and ML.", position: 3, is_active: true, topics: ["Python"] } },
         headers: auth_headers(@admin), as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Data Science", body["name"]
    assert_equal "data-science", body["slug"]
    assert_equal 3, body["position"]
    assert_equal ["Python"], body["topics"]
  end

  test "create returns 401 without a token" do
    post "/api/v1/categories", params: { name: "Nope" }, as: :json

    assert_response :unauthorized
  end

  test "create returns 403 for a non-admin" do
    post "/api/v1/categories", params: { name: "Nope" }, headers: auth_headers(@mentee), as: :json

    assert_response :forbidden
  end

  test "create rejects a blank name" do
    post "/api/v1/categories", params: { category: { name: "" } }, headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
  end

  test "create rejects a duplicate name" do
    post "/api/v1/categories", params: { category: { name: @category.name } }, headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
  end

  test "create rejects a duplicate slug" do
    post "/api/v1/categories",
         params: { category: { name: "Another Category", slug: @category.slug } },
         headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
  end

  test "create rejects an invalid parent" do
    post "/api/v1/categories",
         params: { category: { name: "Orphan", parent_id: 999999 } },
         headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
  end

  test "update keeps the slug stable on rename" do
    patch "/api/v1/categories/#{@category.id}",
          params: { category: { name: "Engineering" } },
          headers: auth_headers(@admin), as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "Engineering", body["name"]
    assert_equal "software-development", body["slug"]
  end

  test "update allows an explicit slug change" do
    patch "/api/v1/categories/#{@category.id}",
          params: { category: { slug: "engineering" } },
          headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "engineering", JSON.parse(response.body)["slug"]
  end

  test "update returns 422 for invalid attributes" do
    patch "/api/v1/categories/#{@category.id}",
          params: { category: { position: -1 } },
          headers: auth_headers(@admin), as: :json

    assert_response :unprocessable_entity
  end

  test "destroy deletes an unused category" do
    unused = Category.create!(name: "Unused", is_active: true)

    delete "/api/v1/categories/#{unused.id}", headers: auth_headers(@admin)

    assert_response :ok
    assert_equal "Category deleted", JSON.parse(response.body)["detail"]
    assert_not Category.exists?(unused.id)
  end

  test "destroy returns 422 when the category is in use" do
    delete "/api/v1/categories/#{@category.id}", headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert_match(/in use/, JSON.parse(response.body)["detail"])
    assert Category.exists?(@category.id)
  end

  test "destroy purges the attached image" do
    @category.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "avatar.png", content_type: "image/png"
    )
    blob_id = @category.image.blob.id

    delete "/api/v1/categories/#{@category.id}", headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert ActiveStorage::Blob.exists?(blob_id)

    unused = Category.create!(name: "Unused With Image", is_active: true)
    unused.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "avatar.png", content_type: "image/png"
    )
    unused_blob_id = unused.image.blob.id

    delete "/api/v1/categories/#{unused.id}", headers: auth_headers(@admin)

    assert_response :ok
    assert_not ActiveStorage::Blob.exists?(unused_blob_id)
  end

  test "image upload returns an absolute URL and metadata" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/avatar.png"), "image/png")

    patch "/api/v1/categories/#{@category.id}/image", params: { image: file }, headers: auth_headers(@admin)

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["image_url"].present?
    assert_match(%r{\Ahttp://}, body["image_url"])
    assert_equal "image/png", body.dig("image_metadata", "content_type")
    assert @category.reload.image.attached?
  end

  test "image upload rejects a non-image" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/plain")

    patch "/api/v1/categories/#{@category.id}/image", params: { image: file }, headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert_equal "Image must be a PNG, JPEG, or WebP image", JSON.parse(response.body)["detail"]
  end

  test "image upload rejects a file larger than 5 MB" do
    large = Tempfile.new(["large", ".png"])
    large.write("a" * (6 * 1024 * 1024))
    large.rewind
    file = Rack::Test::UploadedFile.new(large.path, "image/png")

    patch "/api/v1/categories/#{@category.id}/image", params: { image: file }, headers: auth_headers(@admin)

    assert_response :unprocessable_entity
    assert_equal "Image must be smaller than 5 MB", JSON.parse(response.body)["detail"]
  ensure
    large&.close!
  end

  test "replacing an image purges the previous blob" do
    @category.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "first.png", content_type: "image/png"
    )
    old_blob_id = @category.image.blob.id

    replacement = Rack::Test::UploadedFile.new(Rails.root.join("db/seed_assets/categories/design.jpg"), "image/jpeg")
    patch "/api/v1/categories/#{@category.id}/image", params: { image: replacement }, headers: auth_headers(@admin)

    assert_response :ok
    assert_not ActiveStorage::Blob.exists?(old_blob_id)
    assert @category.reload.image.attached?
  end

  test "image delete returns 204 and clears image_url" do
    @category.image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "avatar.png", content_type: "image/png"
    )

    delete "/api/v1/categories/#{@category.id}/image", headers: auth_headers(@admin)

    assert_response :no_content
    assert_not @category.reload.image.attached?

    get "/api/v1/categories/#{@category.id}"

    assert_response :ok
    assert_nil JSON.parse(response.body)["image_url"]
  end

  test "image upload returns 403 for a non-admin" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/avatar.png"), "image/png")

    patch "/api/v1/categories/#{@category.id}/image", params: { image: file }, headers: auth_headers(@mentee)

    assert_response :forbidden
  end
end
