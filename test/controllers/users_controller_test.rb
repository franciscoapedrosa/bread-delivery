require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin can view users" do
    sign_in users(:admin)
    get users_url
    assert_response :success
  end

  test "distributor cannot view another user" do
    sign_in users(:distributor)
    get user_url(users(:admin))
    assert_redirected_to authenticated_root_url
  end

  test "admin cannot delete own account" do
    admin = users(:admin)
    sign_in admin
    assert_no_difference("User.count") { delete user_url(admin) }
  end

  test "admin can reset a distributor password" do
    admin = users(:admin)
    distributor = users(:distributor)
    sign_in admin

    patch user_url(distributor), params: {
      user: {
        email: distributor.email,
        role: distributor.role,
        password: "nova-password-123",
        password_confirmation: "nova-password-123"
      }
    }

    assert_redirected_to user_url(distributor)
    assert distributor.reload.valid_password?("nova-password-123")
  end
end
