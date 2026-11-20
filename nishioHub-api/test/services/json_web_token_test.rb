require "test_helper"

class JsonWebTokenTest < ActiveSupport::TestCase
  test "encodes and decodes a subject" do
    token = JsonWebToken.encode({ sub: "ada@example.com" }, exp: 1.hour.from_now)
    payload = JsonWebToken.decode(token)

    assert_equal "ada@example.com", payload["sub"]
    assert payload["exp"].present?
  end

  test "raises DecodeError for a tampered token" do
    assert_raises(JsonWebToken::DecodeError) do
      JsonWebToken.decode("not-a-token")
    end
  end

  test "raises DecodeError for an expired token" do
    token = JsonWebToken.encode({ sub: "ada@example.com" }, exp: 1.minute.ago)

    assert_raises(JsonWebToken::DecodeError) do
      JsonWebToken.decode(token)
    end
  end
end
