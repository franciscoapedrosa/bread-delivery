require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  test "bread orders opened from customers return to customers" do
    sign_in users(:admin)
    get customers_path
    assert_select "a[href='#{scheduled_stops_path(origin: 'customers')}']"
    assert_select "a[href='#{new_user_path(origin: 'customers')}']"
    get scheduled_stops_path(origin: "customers")
    assert_select "nav a[href='#{customers_path}']", text: "Voltar"
    get scheduled_stops_path
    assert_select "nav a", text: "Voltar ao início"
  end

  test "editing an address from a route preserves the return destination" do
    sign_in users(:admin)
    customer = customers(:one)
    route = routes(:one)
    stop = route.route_stops.create!(customer: customer, position: 1)
    back_path = route_path(route, anchor: "route-stop-#{stop.id}")

    get route_path(route)
    assert_select "a[href='#{edit_customer_path(customer, origin: 'route', route_id: route.id)}']"

    get edit_customer_path(customer, origin: "route", route_id: route.id)
    assert_select "nav a[href='#{back_path}']", text: "Voltar"
    assert_select "input[name='route_id'][value='#{route.id}']"

    patch customer_path(customer), params: { origin: "route", route_id: route.id, customer: { address: "" } }
    assert_response :unprocessable_entity
    assert_select "nav a[href='#{back_path}']", text: "Voltar"
    assert_select "input[name='route_id'][value='#{route.id}']"

    patch customer_path(customer), params: { origin: "route", route_id: route.id, customer: { address: "Nova morada" } }
    assert_redirected_to back_path
  end

  test "creating access from a customer preselects their profile and role" do
    sign_in users(:admin)
    customer = customers(:one)
    get customer_path(customer)
    assert_select "a[href='#{new_user_path(customer_id: customer.id)}']", text: "Criar"
    get new_user_path(customer_id: customer.id)
    assert_response :success
    assert_select "select[name='user[role]'] option[selected][value='customer']"
    assert_select "select[name='user[existing_customer_id]'] option[selected][value='#{customer.id}']"
  end

  test "upcoming deliveries exclude removed bookings after rescheduling" do
    sign_in users(:admin)
    customer = customers(:one)
    route = routes(:one)
    route.route_stops.create!(customer: customer, position: 1)
    removed = RouteRun.create!(route: route, distributor: users(:distributor), delivery_date: Date.tomorrow, removed: true)
    removed.scheduled_stops.update_all(status: "cancelled")
    replacement = RouteRun.create!(route: route, distributor: users(:distributor), delivery_date: Date.tomorrow)

    get customer_url(customer)

    assert_response :success
    assert_select "a[href='#{route_run_path(removed)}']", count: 0
    assert_select "a[href='#{route_run_path(replacement)}']", count: 1
    assert_select ".planning-grid article", count: 1
    assert RouteRun.exists?(removed.id)
  end

  test "admin can view customers" do
    sign_in users(:admin)
    get customers_url
    assert_response :success
    assert_select "th", text: "Morada", count: 0
    assert_select "th", text: "Estado"
    assert_select "a", text: "Ver detalhes"
    assert_select "a.customer-name-link", count: 0
    assert_select "a", text: "Editar", count: 0
  end

  test "admin sees full customer details on the customer page" do
    sign_in users(:admin)
    customer = customers(:one)
    get customer_url(customer)
    assert_response :success
    assert_select "h1", customer.name
    assert_select "dd", text: customer.address
    assert_select "a", text: "Editar cliente"
    assert_select "nav a", text: "Voltar"
    assert_select "nav a[href='#{customers_path}']", text: "Voltar"
  end

  test "editing from customer details returns to that customer" do
    sign_in users(:admin)
    customer = customers(:one)

    get edit_customer_url(customer, origin: "customer")

    assert_response :success
    assert_select "nav a[href='#{customer_path(customer)}']", text: "Voltar"
    assert_select "input[name='origin'][value='customer']"
  end

  test "distributor cannot manage all customers" do
    sign_in users(:distributor)
    get customers_url
    assert_redirected_to authenticated_root_url
  end

  test "distributor can view assigned customers" do
    sign_in users(:distributor)
    get my_customers_url
    assert_response :success
    assert_select "td", text: customers(:one).name
    assert_select "td", text: customers(:two).name, count: 0
  end
end
