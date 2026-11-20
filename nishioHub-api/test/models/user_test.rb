require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "password is stored as a bcrypt hash and authenticates" do
    user = User.new(full_name: "Ada", email: "ada@example.com")
    user.password = "secret123"

    assert user.hashed_password.start_with?("$2")
    assert user.authenticate("secret123")
    assert_not user.authenticate("wrong")
  end

  test "email must be unique" do
    role = create_role("mentee")
    create_user(email: "ada@example.com", role: role)

    duplicate = User.new(full_name: "Other", email: "ada@example.com", role: role)
    duplicate.password = "secret123"

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "a user may have no role" do
    user = User.new(full_name: "No Role", email: "norole@example.com", phone_number: "+256700010101")
    user.password = "secret123"

    assert user.valid?
    assert_nil user.role
  end
end
