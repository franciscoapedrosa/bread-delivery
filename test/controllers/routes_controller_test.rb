require "test_helper"

class RoutesControllerTest < ActionDispatch::IntegrationTest
  test "route names are plain text in the admin list" do
    sign_in users(:admin)

    get routes_url

    assert_response :success
    assert_select "td strong", text: routes(:one).name
    assert_select "a[href='#{route_path(routes(:one))}']", text: routes(:one).name, count: 0
    assert_select "a[href='#{route_path(routes(:one))}']", text: "Clientes e percurso"
  end

  test "back returns to the list when editing from the list even after validation fails" do
    sign_in users(:admin)
    get edit_route_url(routes(:one), origin: "list")
    assert_select "nav a[href=?]", routes_path, text: "Voltar"
    assert_select "input[name=origin][value=list]"
    patch route_url(routes(:one)), params: { origin: "list", route: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "nav a[href=?]", routes_path, text: "Voltar"
    assert_select "input[name=origin][value=list]"
  end

  test "route origin and unknown origins return to the route itself" do
    sign_in users(:admin)
    [ "route", nil, "https://example.org" ].each do |origin|
      get edit_route_url(routes(:one), origin: origin)
      assert_response :success
      assert_select "nav a[href=?]", route_path(routes(:one)), text: "Voltar"
    end
  end

  test "distributor sees only assigned routes" do
    sign_in users(:distributor)
    get routes_url
    assert_redirected_to route_runs_url
  end

  test "distributor cannot edit a route" do
    sign_in users(:distributor)
    get edit_route_url(routes(:one))
    assert_redirected_to authenticated_root_url
  end
end
