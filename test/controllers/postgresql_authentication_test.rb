require "test_helper"

class PostgresqlAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    skip "PostgreSQL-only end-to-end RLS tests" unless DatabaseAccess.postgresql?
    @connection = ActiveRecord::Base.connection
    @email = users(:distributor).email
    @user_id = users(:distributor).id
    @connection.execute("SET LOCAL ROLE bread_app")
    DatabaseAccess.set_context(role: "", user_id: nil)
  end

  teardown do
    if @connection
      @connection.execute("RESET ROLE")
      DatabaseAccess.set_context(role: "system")
    end
  end

  test "real authentication establishes context and restores pooled connection" do
    post user_session_path, params: { user: { email: @email, password: "password123" } }
    assert_response :redirect
    get authenticated_root_path
    assert_response :success
    get users_path, as: :json
    assert_response :forbidden
    assert_equal 0, User.count
  end

  test "failed authentication commits the lock counter through Warden" do
    5.times { post user_session_path, params: { user: { email: @email, password: "wrong-password" } } }
    DatabaseAccess.with_context(role: "auth") { assert User.find(@user_id).access_locked? }
    assert_equal 0, User.count
  end

  test "recovery can find encrypted email and reset the password" do
    assert_difference "ActionMailer::Base.deliveries.count", 1 do
      post user_password_path, params: { user: { email: @email } }
    end
    assert_response :redirect
    token = nil
    DatabaseAccess.with_context(role: "auth") { token = User.find(@user_id).send_reset_password_instructions }
    put user_password_path, params: { user: { reset_password_token: token, password: "new-test-password", password_confirmation: "new-test-password" } }
    assert_response :redirect
    DatabaseAccess.with_context(role: "auth") { assert User.find(@user_id).valid_password?("new-test-password") }
  end

  test "customer view admin approval and distributor completion use the restricted connection" do
    @connection.execute("RESET ROLE")
    DatabaseAccess.set_context(role: "system")
    client = User.new(email: "pg-customer@example.com", password: "password123", role: "customer")
    client.customer = customers(:one)
    client.save!
    route = routes(:one)
    route.route_stops.create!(customer: customers(:one), position: 1)
    run = RouteRun.create!(route: route, distributor: users(:distributor), delivery_date: Date.tomorrow)
    stop = run.scheduled_stops.first
    stop.update!(requested_quantity: 8, approval_status: "pending")
    admin_email = users(:admin).email
    @connection.execute("SET LOCAL ROLE bread_app")
    DatabaseAccess.set_context(role: "", user_id: nil)

    post user_session_path, params: { user: { email: client.email, password: "password123" } }
    get scheduled_stops_path
    assert_response :success
    assert_select "article", count: 1
    assert_select "body", text: /#{Regexp.escape(customers(:one).address)}/
    delete destroy_user_session_path

    post user_session_path, params: { user: { email: admin_email, password: "password123" } }
    patch approve_scheduled_stop_path(stop), params: { requested_quantity: 8 }
    assert_response :redirect
    delete destroy_user_session_path

    post user_session_path, params: { user: { email: @email, password: "password123" } }
    get route_run_path(run)
    assert_response :success
    patch scheduled_stop_path(stop), params: { scheduled_stop: { status: "delivered" } }
    assert_response :redirect
    DatabaseAccess.with_context(role: "distributor", user_id: @user_id) do
      assert_equal "delivered", stop.reload.status
      assert_equal 8, stop.approved_quantity
    end
  end
end
