require "test_helper"

class RoutePlanningControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 9, 16, 12)
    @customer_user = User.new(email: "client@example.com", password: "password123", role: "customer")
    @customer_user.customer = customers(:one)
    @customer_user.save!
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    routes(:two).route_stops.create!(customer: customers(:two), position: 1)
    @run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow)
    @other_run = RouteRun.create!(route: routes(:two), distributor: users(:other_distributor), delivery_date: Date.tomorrow)
    @stop = @run.scheduled_stops.first
  end

  teardown { travel_back }

  test "admin can create a client account and profile together" do
    sign_in users(:admin)
    assert_difference [ "User.count", "Customer.count" ], 1 do
      post users_path, params: { user: { email: "newclient@example.com", password: "password123", role: "customer", customer_attributes: { name: "Maria", address: "Rua das Flores, 10, Lisboa" } } }
    end
    assert_response :redirect
    assert_equal "Maria", User.find_by!(email: "newclient@example.com").customer.name
  end

  test "deliveries move to history only after their day and stay scoped to the customer" do
    sign_in @customer_user
    travel_to @run.delivery_date.in_time_zone.change(hour: 23, min: 59) do
      get scheduled_stops_path
      assert_select "article", count: 1
      get scheduled_stops_path(history: "1")
      assert_select "article", count: 0
    end

    travel_to (@run.delivery_date + 1).in_time_zone do
      get scheduled_stops_path
      assert_select "article", count: 0
      get scheduled_stops_path(history: "1")
      assert_response :success
      assert_select "article", count: 1
      assert_select "form", count: 0
      assert_select "p", text: /South Route/, count: 0

      sign_in users(:admin)
      get scheduled_stops_path(history: "1")
      assert_response :success
      assert_select "article", count: 2
      assert_select "form", count: 0
      get route_runs_path(week: @run.delivery_date)
      assert_select ".route-run-card", count: 0
    end
  end

  test "admin can associate an existing customer without replacing their details" do
    sign_in users(:admin)
    assert_no_difference "Customer.count" do
      post users_path, params: { user: { email: "existing@example.com", password: "password123", role: "customer", existing_customer_id: customers(:two).id } }
    end
    assert_response :redirect
    assert_equal customers(:two), User.find_by!(email: "existing@example.com").customer
  end

  test "client sees only assigned dates and cannot submit or approve another order" do
    sign_in @customer_user
    get scheduled_stops_path
    assert_response :success
    assert_select "h1", "O meu pão"
    assert_select "p", text: /South Route/, count: 0
    patch scheduled_stop_path(@other_run.scheduled_stops.first), params: { scheduled_stop: { requested_quantity: 99 } }
    assert_response :not_found
    patch approve_scheduled_stop_path(@stop)
    assert_redirected_to authenticated_root_path
    assert_nil @stop.reload.approved_quantity
  end

  test "admin sees the clients who have not submitted bread quantities" do
    sign_in users(:admin)

    get scheduled_stops_path

    assert_response :success
    assert_select "#unsubmitted-customers-title", text: "Clientes por submeter quantidades de pão"
    assert_select ".unsubmitted-customers li", text: customers(:one).name
    assert_select ".unsubmitted-customers li", text: customers(:two).name
  end

  test "customer cannot bypass approval by submitting extra attributes" do
    sign_in @customer_user
    patch scheduled_stop_path(@stop), params: { scheduled_stop: { requested_quantity: 7, approved_quantity: 7, approval_status: "approved", status: "delivered" } }
    assert_equal 7, @stop.reload.requested_quantity
    assert_nil @stop.approved_quantity
    assert_equal "pending", @stop.status
  end

  test "distributor sees and changes only assigned routes" do
    sign_in users(:distributor)
    get route_runs_path
    assert_response :success
    assert_select "h3", routes(:one).name
    assert_select ".route-distributor", text: /Distribuidor:.*#{Regexp.escape(users(:distributor).email)}/
    assert_select ".route-statuses .state-pill", count: 3
    assert_select "p", text: /Rota 1 do dia/, count: 0
    assert_select "h3", text: routes(:two).name, count: 0
    get route_run_path(@other_run)
    assert_response :not_found
    patch scheduled_stop_path(@other_run.scheduled_stops.first), params: { scheduled_stop: { status: "cancelled" } }
    assert_response :not_found
    patch scheduled_stop_path(@stop), params: { scheduled_stop: { status: "cancelled", address: "Changed" } }
    assert_equal "cancelled", @stop.reload.status
    assert_equal customers(:one).address, @stop.address
  end

  test "admin approval then distributor delivery completes the flow" do
    sign_in @customer_user
    patch scheduled_stop_path(@stop), params: { scheduled_stop: { requested_quantity: 10 } }
    sign_in users(:admin)
    get scheduled_stops_path
    assert_response :success
    patch approve_scheduled_stop_path(@stop), params: { requested_quantity: 10 }
    assert_equal 10, @stop.reload.approved_quantity
    sign_in users(:distributor)
    get route_run_path(@run)
    assert_response :success
    assert_select "a", text: "Google Maps"
    patch scheduled_stop_path(@stop), params: { scheduled_stop: { status: "delivered" } }
    assert_equal "delivered", @stop.reload.status
  end

  test "admin must send a rejection reason and customer can read it" do
    assert @stop.request_bread(6)
    sign_in users(:admin)

    patch reject_scheduled_stop_path(@stop), params: { requested_quantity: 6, rejection_reason: "Já não é possível alterar a produção." }

    assert_equal "rejected", @stop.reload.approval_status
    assert_equal "Já não é possível alterar a produção.", @stop.rejection_reason
    sign_in @customer_user
    get scheduled_stops_path
    assert_response :success
    assert_select ".rejection-note", text: /Já não é possível alterar a produção\./
    assert_select "input[type='submit'][value='Enviar novo pedido']"

    patch scheduled_stop_path(@stop), params: { scheduled_stop: { requested_quantity: 4 } }
    assert_equal "pending", @stop.reload.approval_status
    assert_equal 4, @stop.requested_quantity
    assert_nil @stop.rejection_reason
  end

  test "admin planning and edit pages render" do
    sign_in users(:admin)
    [ new_user_path, edit_user_path(users(:admin)), new_route_run_path, route_path(routes(:one)), route_run_path(@run), customers_path, customer_path(customers(:one)), authenticated_root_path ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "route journey has one back button returning to the selected week" do
    sign_in users(:admin)
    selected_week = @run.delivery_date.beginning_of_week

    get route_run_path(@run, week: selected_week.iso8601)

    assert_response :success
    assert_select "nav a", count: 1
    assert_select "nav a[href='#{route_runs_path(week: selected_week.iso8601)}']", text: "Voltar"
    assert_select "a", text: "Voltar à semana", count: 0
    assert_select "summary.route-edit-link", text: "Editar"
    assert_select "summary", text: "Alterar distribuidor ou ordem da rota", count: 0
  end

  test "route journey opened from bread requests returns to bread requests" do
    assert @stop.request_bread(8)
    sign_in users(:admin)

    get scheduled_stops_path

    assert_response :success
    assert_select "a[href='#{route_run_path(@run, origin: "bread_requests")}']", text: "Ver percurso"

    get route_run_path(@run, origin: "bread_requests")

    assert_response :success
    assert_select "nav a", count: 1
    assert_select "nav a[href='#{scheduled_stops_path}']", text: "Voltar"
  end
end
