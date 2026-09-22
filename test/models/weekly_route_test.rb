require "test_helper"

class WeeklyRouteTest < ActiveSupport::TestCase
  test "new agenda replaces old removals but respects its own single day exclusions" do
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    old_run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.current, position: 1, removed: true)
    old_run.scheduled_stops.update_all(status: "cancelled")
    schedule = WeeklyRoute.create!(route: routes(:one), distributor: users(:distributor), starts_on: Date.current, days: "all", position: 1)

    WeeklyRoute.materialize_through!(Date.current)
    replacement = RouteRun.find_by!(route_id: schedule.route_id, delivery_date: Date.current, removed: false)
    assert_not_equal old_run.id, replacement.id
    assert old_run.reload.removed?
    assert_equal "cancelled", old_run.scheduled_stops.first.status
    assert_nil replacement.scheduled_stops.first.requested_quantity
    replacement.update!(removed: true)
    assert_no_difference "RouteRun.count" do
      WeeklyRoute.materialize_through!(Date.current)
    end
  end

  test "weekdays repeat without duplicating deliveries or copying quantities" do
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    schedule = WeeklyRoute.create!(route: routes(:one), distributor: users(:distributor), starts_on: Date.current, days: "weekdays", position: 1)
    last_date = Date.current + 14
    WeeklyRoute.materialize_through!(last_date)
    runs = RouteRun.where(weekly_route_id: schedule.id)
    expected = (Date.current..last_date).count { |date| (1..5).cover?(date.wday) }
    assert_equal expected, runs.count
    assert_no_difference "RouteRun.count" do
      WeeklyRoute.materialize_through!(last_date)
    end
    assert runs.all? { |run| run.scheduled_stops.all? { |stop| stop.requested_quantity.nil? && stop.approval_status == "awaiting_request" } }
    schedule.update!(days: "all")
    WeeklyRoute.materialize_through!(last_date)
    assert_equal 15, runs.count
  end
end
