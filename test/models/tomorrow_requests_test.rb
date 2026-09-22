require "test_helper"

class TomorrowRequestsTest < ActiveSupport::TestCase
  test "only tomorrow is open and missing requests stop counting at 23h" do
    travel_to Date.current.in_time_zone.change(hour: 12) do
      routes(:one).route_stops.create!(customer: customers(:one), position: 1)
      tomorrow = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow)
      later = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow + 1)
      assert tomorrow.scheduled_stops.first.open_for_request?
      assert_not later.scheduled_stops.first.request_bread(10)
      assert_equal [ tomorrow.scheduled_stops.first.id ], ScheduledStop.awaiting_tomorrow_request.pluck(:id)
      travel 11.hours
      assert_not tomorrow.scheduled_stops.first.open_for_request?
      assert_empty ScheduledStop.awaiting_tomorrow_request
    end
  end
end
