require "test_helper"

class RouteStopsControllerTest < ActionDispatch::IntegrationTest
  test "arrows swap neighbours and respect the ends even with duplicate positions" do
    route = routes(:one)
    first = route.route_stops.create!(customer: customers(:one), position: 1)
    second = route.route_stops.create!(customer: customers(:two), position: 1)
    sign_in users(:admin)

    patch route_route_stop_path(route, second), params: { direction: "up" }
    assert_response :see_other
    assert_equal [ second.id, first.id ], route.route_stops.ordered.pluck(:id)
    assert_equal [ 1, 2 ], route.route_stops.ordered.pluck(:position)
    patch route_route_stop_path(route, second), params: { direction: "up" }
    assert_equal [ second.id, first.id ], route.route_stops.ordered.pluck(:id)
    patch route_route_stop_path(route, second), params: { direction: "down" }
    assert_equal [ first.id, second.id ], route.route_stops.ordered.pluck(:id)

    sign_in users(:distributor)
    patch route_route_stop_path(route, first), params: { direction: "down" }
    assert_redirected_to authenticated_root_path
    assert_equal [ first.id, second.id ], route.route_stops.ordered.pluck(:id)
  end
end
