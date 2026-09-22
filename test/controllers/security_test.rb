require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  test "login directs password recovery to the administrator" do
    get new_user_session_path
    assert_response :success
    assert_select "p", text: "Para recuperar a palavra-passe, contacte o administrador."
    assert_select "a[href='tel:+351917281389']", text: "📞 Ligar ao administrador"
    assert_select "a[href='sms:+351917281389']", text: "💬 Enviar SMS"
    assert_select "a[href=?]", new_user_password_path, count: 0
  end

  test "all business endpoints require authentication including JSON" do
    paths = [ users_path, customers_path, routes_path, route_runs_path, scheduled_stops_path, bakery_path, vehicles_path, deliveries_path, my_customers_path ]
    paths.each do |path|
      get path, as: :json
      assert_response :unauthorized, path
    end
    post users_path, params: { user: { role: "admin" } }, as: :json
    assert_response :unauthorized
    patch customer_path(customers(:one)), params: { customer: { name: "Forbidden" } }, as: :json
    assert_response :unauthorized
  end

  test "non admins cannot escalate roles through JSON" do
    sign_in users(:distributor)
    patch user_path(users(:distributor)), params: { user: { role: "admin" } }, as: :json
    assert_response :forbidden
    assert_equal "distributor", users(:distributor).reload.role
  end

  test "a remote week cannot trigger unbounded schedule generation" do
    sign_in users(:distributor)
    get route_runs_path(week: "9999-12-01")
    assert_redirected_to route_runs_path
  end

  test "login is blocked after five wrong passwords and unlocks after fifteen minutes" do
    user = users(:admin)
    5.times { post user_session_path, params: { user: { email: user.email, password: "wrong-password" } } }
    assert user.reload.access_locked?
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    assert_response :unprocessable_entity
    travel 16.minutes do
      post user_session_path, params: { user: { email: user.email.upcase, password: "password123" } }
      assert_response :redirect
      assert_not user.reload.access_locked?
    end
  end

  test "IP rate limit also covers nonexistent accounts" do
    20.times { post user_session_path, params: { user: { email: "missing@example.com", password: "wrong" } } }
    post user_session_path, params: { user: { email: "different@example.com", password: "wrong" } }
    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
    assert_not LoginThrottle.pluck(:key).join.include?("example.com")
    travel 16.minutes do
      post user_session_path, params: { user: { email: "missing@example.com", password: "wrong" } }
      assert_response :unprocessable_entity
    end
  end

  test "personal data is encrypted at rest and login lookup still works" do
    user = users(:admin)
    customer = customers(:one)
    connection = ActiveRecord::Base.connection
    raw_email = connection.select_value("SELECT email FROM users WHERE id = #{user.id}")
    assert ActiveRecord::Encryption.encryptor.encrypted?(raw_email)
    assert_not_includes raw_email, user.email
    assert_equal user, User.find_for_database_authentication(email: user.email.upcase)
    duplicate = User.new(email: user.email.upcase, password: "password123", role: "distributor")
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
    %w[name address].each do |field|
      raw = connection.select_value("SELECT #{field} FROM customers WHERE id = #{customer.id}")
      assert ActiveRecord::Encryption.encryptor.encrypted?(raw)
      assert_equal customer.public_send(field), Customer.find(customer.id).public_send(field)
    end
    assert user.valid_password?("password123")
    assert_match(/\A\$2[aby]\$/, user.encrypted_password)
    assert_not_equal "password123", user.encrypted_password
  end

  test "password recovery is rate limited with a generic response" do
    5.times { post user_password_path, params: { user: { email: "missing@example.com" } } }
    post user_password_path, params: { user: { email: "missing@example.com" } }
    assert_response :too_many_requests
  end
end
