require "test_helper"

class Api::V1::ConversationsControllerTest < ActionDispatch::IntegrationTest
  def person(email = "chat@example.com", role = "mentee")
    User.create!(full_name: "Chat #{role.capitalize}", email: email, password: "secret123", role: create_role(role),
      phone_number: "+256#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}")
  end

  def direct(user, other)
    conversation = Conversation.create!(creator: user, kind: "direct", direct_key: [user.id, other.id].sort.join(":"))
    [user, other].each { |participant| conversation.conversation_memberships.create!(user: participant) }
    conversation
  end

  test "messaging endpoints require authentication" do
    get "/api/v1/conversations"
    assert_response :unauthorized
    get "/api/v1/conversations/contacts"
    assert_response :unauthorized
    post "/api/v1/conversations", params: { participant_ids: [1] }, as: :json
    assert_response :unauthorized
  end

  test "direct conversations are idempotent in either participant order and cannot target oneself" do
    user = person
    other = person("other-chat@example.com", "mentor")
    post "/api/v1/conversations", headers: auth_headers(user), params: { participant_ids: [other.id] }, as: :json
    assert_response :ok
    id = response.parsed_body["id"]
    post "/api/v1/conversations", headers: auth_headers(other), params: { participant_ids: [user.id] }, as: :json
    assert_response :ok
    assert_equal id, response.parsed_body["id"]
    assert_equal 2, Conversation.find(id).conversation_memberships.count
    post "/api/v1/conversations", headers: auth_headers(user), params: { participant_ids: [user.id] }, as: :json
    assert_response :unprocessable_entity
    post "/api/v1/conversations", headers: auth_headers(user), params: { participant_ids: [{ id: other.id }] }, as: :json
    assert_response :unprocessable_entity
  end

  test "nonmembers cannot read send mark read or download attachments" do
    user = person
    other = person("other-private-chat@example.com")
    stranger = person("stranger-chat@example.com")
    conversation = direct(user, other)
    message = conversation.chat_messages.create!(sender: user, content: "Private text")
    get "/api/v1/conversations/#{conversation.id}", headers: auth_headers(stranger)
    assert_response :not_found
    get "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(stranger)
    assert_response :not_found
    post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(stranger), params: { message: { content: "Intrusion" } }, as: :json
    assert_response :not_found
    patch "/api/v1/conversations/#{conversation.id}/read", headers: auth_headers(stranger), params: { last_message_id: message.id }, as: :json
    assert_response :not_found
    get "/api/v1/conversations/#{conversation.id}/messages/#{message.id}/attachment", headers: auth_headers(stranger)
    assert_response :not_found
    get "/api/v1/conversations", headers: auth_headers(stranger), params: { q: "Private" }
    assert_empty response.parsed_body["conversations"]
  end

  test "sending is persisted deduplicated and notifies recipients only" do
    user = person
    other = person("recipient-chat@example.com", "mentor")
    conversation = direct(user, other)
    2.times do
      post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user), params: { message: { content: "Hello mentor", client_nonce: "retry-1", sender_id: other.id } }, as: :json
      assert_response :created
    end
    assert_equal 1, conversation.chat_messages.count
    message = conversation.chat_messages.first
    assert_equal user.id, message.sender_id
    assert_equal 1, other.notifications.where(source_key: "chat-message-#{message.id}").count
    assert_empty user.notifications
    get "/api/v1/conversations/unread-count", headers: auth_headers(other)
    assert_equal 1, response.parsed_body["unread"]
    patch "/api/v1/conversations/#{conversation.id}/read", headers: auth_headers(other), params: { last_message_id: message.id }, as: :json
    assert_response :ok
    get "/api/v1/conversations/unread-count", headers: auth_headers(other)
    assert_equal 0, response.parsed_body["unread"]
    assert other.notifications.find_by!(source_key: "chat-message-#{message.id}").read
    get "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user)
    assert_includes response.parsed_body["messages"].first["read_by"], other.id
  end

  test "groups require a title and three active members and notify all other members" do
    user = person
    other = person("group-one@example.com")
    third = person("group-two@example.com", "mentor")
    post "/api/v1/conversations", headers: auth_headers(user), params: { kind: "group", title: "STEM Innovators", participant_ids: [other.id, third.id] }, as: :json
    assert_response :ok
    conversation = Conversation.find(response.parsed_body["id"])
    assert_equal "group", conversation.kind
    assert_equal 3, conversation.users.count
    post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user), params: { message: { content: "Welcome everyone", client_nonce: "group-1" } }, as: :json
    assert_response :created
    assert_equal 1, other.notifications.where(href: "/messages/#{conversation.id}").count
    assert_equal 1, third.notifications.where(href: "/messages/#{conversation.id}").count
    post "/api/v1/conversations", headers: auth_headers(user), params: { kind: "group", title: "", participant_ids: [other.id, third.id] }, as: :json
    assert_response :unprocessable_entity
    other.update!(is_active: false)
    post "/api/v1/conversations", headers: auth_headers(user), params: { participant_ids: [other.id] }, as: :json
    assert_response :unprocessable_entity
  end

  test "attachments download privately without exposing signed blob URLs" do
    user = person
    other = person("attachment-recipient@example.com")
    conversation = direct(user, other)
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/plain")
    post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user), params: { message: { content: "Notes", client_nonce: "attachment-1", attachment: file } }
    assert_response :created
    message_id = response.parsed_body["id"]
    assert_equal "notes.txt", response.parsed_body.dig("attachment", "filename")
    refute_includes response.body, "rails/active_storage"
    get "/api/v1/conversations/#{conversation.id}/messages/#{message_id}/attachment", headers: auth_headers(other)
    assert_response :ok
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_equal File.read(Rails.root.join("test/fixtures/files/notes.txt")), response.body
    unsafe = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/notes.txt"), "text/html")
    post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user), params: { message: { attachment: unsafe } }
    assert_response :unprocessable_entity
    oversized = conversation.chat_messages.new(sender: user)
    oversized.attachment.attach(io: StringIO.new("x" * (10.megabytes + 1)), filename: "big.txt", content_type: "text/plain")
    refute oversized.valid?
    assert_includes oversized.errors.full_messages.join, "10 MB"
    post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user), params: { message: { attachment: "not-an-upload" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "message pagination and read cursor stay within the selected conversation" do
    user = person
    other = person("paging-recipient@example.com")
    conversation = direct(user, other)
    52.times { |index| conversation.chat_messages.create!(sender: user, content: "Message #{index}") }
    get "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(other)
    assert_response :ok
    assert_equal 50, response.parsed_body["messages"].size
    assert response.parsed_body["has_more"]
    oldest = response.parsed_body["oldest_id"]
    get "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(other), params: { before_id: oldest }
    assert_equal 2, response.parsed_body["messages"].size
    stranger = person("other-conversation@example.com")
    foreign = direct(user, stranger).chat_messages.create!(sender: stranger, content: "Another chat")
    patch "/api/v1/conversations/#{conversation.id}/read", headers: auth_headers(other), params: { last_message_id: foreign.id }, as: :json
    assert_response :not_found
  end

  test "blank and oversized messages are rejected and contacts exclude private email" do
    user = person
    other = person("contact-search@example.com", "mentor")
    conversation = direct(user, other)
    [" ", "a" * 5001].each do |content|
      post "/api/v1/conversations/#{conversation.id}/messages", headers: auth_headers(user), params: { message: { content: content } }, as: :json
      assert_response :unprocessable_entity
    end
    get "/api/v1/conversations/contacts", headers: auth_headers(user), params: { q: "Chat Mentor" }
    assert_response :ok
    assert_includes response.parsed_body.map { |person| person["id"] }, other.id
    refute_includes response.body, other.email
  end
end
