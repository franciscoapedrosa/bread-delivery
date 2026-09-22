require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "customer account creation returns to customers even after validation errors" do
    sign_in users(:admin)
    get new_user_path(origin: "customers")
    assert_select "nav a[href='#{customers_path}']", text: "Voltar"
    assert_select "input[name='origin'][value='customers']"

    post users_path, params: { origin: "customers", user: { email: "", role: "customer" } }
    assert_response :unprocessable_entity
    assert_select "nav a[href='#{customers_path}']", text: "Voltar"
  end

  test "user editing returns to users after validation errors too" do
    sign_in users(:admin)
    get edit_user_path(users(:distributor))
    assert_select "nav a[href='#{users_path}']", text: "Voltar"
    patch user_path(users(:distributor)), params: { user: { email: "", role: "distributor" } }
    assert_response :unprocessable_entity
    assert_select "nav a[href='#{users_path}']", text: "Voltar"
  end

  test "admin sees a coloured label for each user role" do
    sign_in users(:admin)

    get users_url

    assert_response :success
    assert_select ".role-pill.role-admin", text: "Administrador"
    assert_select ".role-pill.role-distributor", text: "Distribuidor"
  end

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

  test "unsupported roles are rejected" do
    admin = users(:admin)
    distributor = users(:distributor)
    sign_in admin

    patch user_url(distributor), params: {
      user: { email: distributor.email, role: "owner", password: "" }
    }

    assert_response :unprocessable_entity
    assert_equal "distributor", distributor.reload.role
  end
end
