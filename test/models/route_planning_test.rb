require "test_helper"

class RoutePlanningTest < ActiveSupport::TestCase
  setup do
    @route = routes(:one)
    @route.route_stops.create!(customer: customers(:one), position: 2)
    @route.route_stops.create!(customer: customers(:two), position: 1)
    @run = RouteRun.create!(route: @route, distributor: users(:distributor), delivery_date: Date.current + 2, position: 1)
    @stop = @run.scheduled_stops.find_by!(customer: customers(:one))
  end

  test "planning snapshots customer order and address" do
    assert_equal [ customers(:two).id, customers(:one).id ], @run.scheduled_stops.ordered.pluck(:customer_id)
    original_address = @stop.address
    customers(:one).update!(address: "Nova morada")
    @route.route_stops.find_by!(customer: customers(:one)).update!(position: 1)
    assert_equal original_address, @stop.reload.address
    assert_equal 2, @stop.position
  end

  test "only approved quantities count and editing requests clears approval" do
    assert @stop.request_bread(12)
    assert_equal 0, @run.total_bread
    assert @stop.decide!("approved")
    assert_equal 12, @run.reload.total_bread
    assert @stop.request_bread(8)
    assert_nil @stop.approved_quantity
    assert_equal "pending", @stop.approval_status
    assert_equal 0, @run.reload.total_bread
  end

  test "request deadline is exclusive at 23 Lisbon time" do
    travel_to(@run.cutoff - 1.second) { assert @stop.request_bread(4) }
    travel_to(@run.cutoff) { assert_not @stop.request_bread(7) }
    assert_equal 4, @stop.reload.requested_quantity
  end

  test "approval cannot accept a different quantity from the one the admin saw" do
    assert @stop.request_bread(12)
    assert_not @stop.decide!("approved", expected_quantity: 5)
    assert_nil @stop.reload.approved_quantity
    assert_equal "pending", @stop.approval_status
  end

  test "cutoff remains 23 on Lisbon daylight saving change" do
    run = RouteRun.new(delivery_date: Date.new(2026, 10, 25))
    assert_equal "2026-10-24 23:00 +0100", run.cutoff.strftime("%Y-%m-%d %H:%M %z")
  end

  test "cannot mark unapproved bread as delivered" do
    assert_not @stop.update(status: "delivered")
    @stop.reload
    assert @stop.request_bread(5)
    assert @stop.decide!("approved")
    assert @stop.update(status: "delivered")
  end

  test "cancelled delivery does not count or accept new requests" do
    assert @stop.request_bread(5)
    assert @stop.decide!("approved")
    @stop.update!(status: "cancelled")
    assert_equal 0, @run.reload.total_bread
    assert_not @stop.request_bread(6)
  end

  test "quantities must be valid and zero is allowed" do
    [ -1, "abc", "1.5", 100001, "" ].each do |quantity|
      assert_not @stop.reload.request_bread(quantity)
    end
    assert @stop.reload.request_bread(0)
    assert @stop.decide!("approved")
    assert_equal 0, @stop.approved_quantity
  end

  test "a route needs active clients and a distributor" do
    run = RouteRun.new(route: routes(:two), distributor: users(:admin), delivery_date: Date.tomorrow)
    assert_not run.valid?
    assert run.errors[:base].any?
  end

  test "same route cannot be scheduled twice for one date" do
    assert_not RouteRun.new(route: @route, distributor: users(:other_distributor), delivery_date: @run.delivery_date).valid?
  end
end
