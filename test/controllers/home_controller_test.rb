require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { travel_to Date.current.in_time_zone.change(hour: 12) }
  teardown { travel_back }
  test "should get index" do
    sign_in users(:admin)
    get home_index_url
    assert_response :success
    assert_select "form[action='#{destroy_user_session_path}'] .btn-logout", text: "Terminar sessão"
  end

  test "admin sees how many bread requests have not been submitted" do
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow)
    stop = run.scheduled_stops.first
    RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.current + 2)
    sign_in users(:admin)

    get home_index_url

    assert_select ".request-status-alert", text: "1"

    stop.update!(requested_quantity: 3, approval_status: "pending")
    get home_index_url

    assert_select ".request-status-ok", text: "✓"
  end

  test "customer sees pending and rejected delivery day counts" do
    customer_user = User.new(email: "home-client@example.com", password: "password123", role: "customer")
    customer_user.customer = customers(:one)
    customer_user.save!
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    routes(:two).route_stops.create!(customer: customers(:one), position: 1)
    pending_run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow)
    rejected_run = RouteRun.create!(route: routes(:two), distributor: users(:other_distributor), delivery_date: Date.tomorrow)
    assert pending_run.scheduled_stops.first.request_bread(4)
    rejected_stop = rejected_run.scheduled_stops.first
    assert rejected_stop.request_bread(2)
    assert rejected_stop.decide!("rejected", rejection_reason: "Quantidade indisponível.")
    sign_in customer_user

    get home_index_url

    assert_response :success
    assert_select ".request-decision-pending", text: "1 por aprovar"
    assert_select ".request-decision-rejected", text: "1 Recusado"
  end

  test "redirects guests to sign in" do
    get home_index_url
    assert_redirected_to new_user_session_url
  end
end
