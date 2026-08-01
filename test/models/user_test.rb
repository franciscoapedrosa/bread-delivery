require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "role must be supported" do
    user = User.new(email: "invalid@example.com", password: "password123", role: "driver")

    assert_not user.valid?
    assert_includes user.errors[:role], "não está incluído na lista"
  end

  test "role helpers identify users" do
    assert users(:admin).admin?
    assert users(:distributor).distributor?
  end
end
