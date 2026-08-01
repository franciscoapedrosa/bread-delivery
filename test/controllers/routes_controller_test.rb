require "test_helper"

class RoutesControllerTest < ActionDispatch::IntegrationTest
  test "distributor sees only assigned routes" do
    sign_in users(:distributor)
    get routes_url
    assert_response :success
    assert_select "li", text: routes(:one).name
    assert_select "li", text: routes(:two).name, count: 0
  end

  test "distributor cannot edit a route" do
    sign_in users(:distributor)
    get edit_route_url(routes(:one))
    assert_redirected_to authenticated_root_url
  end
end
