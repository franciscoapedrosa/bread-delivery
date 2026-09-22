require "test_helper"

class RowSecurityTest < ActiveSupport::TestCase
  setup do
    skip "RLS requires TEST_DATABASE_URL pointing at the isolated PostgreSQL test database" unless DatabaseAccess.postgresql?
    @connection = ActiveRecord::Base.connection
    DatabaseAccess.set_context(role: "system")
    @client = User.new(email: "rls-client@example.com", password: "password123", role: "customer")
    @client.customer = customers(:one)
    @client.save!
    @route = routes(:one)
    @route.route_stops.create!(customer: customers(:one), position: 1)
    routes(:two).route_stops.create!(customer: customers(:two), position: 1)
    @run = RouteRun.create!(route: @route, distributor: users(:distributor), delivery_date: Date.tomorrow)
    @other_run = RouteRun.create!(route: routes(:two), distributor: users(:other_distributor), delivery_date: Date.tomorrow)
    @stop = @run.scheduled_stops.first
    @other_stop = @other_run.scheduled_stops.first
    @admin_id = users(:admin).id
    @distributor_id = users(:distributor).id
    @connection.execute("SET LOCAL ROLE bread_app")
    DatabaseAccess.set_context(role: "", user_id: nil)
  end

  teardown do
    if @connection
      @connection.execute("RESET ROLE")
      DatabaseAccess.set_context(role: "system")
    end
  end

  test "restricted connection has RLS and no context sees no records" do
    DatabaseAccess.verify_runtime_role!
    [ User, Customer, Delivery, Route, RouteStop, RouteRun, ScheduledStop, WeeklyRoute, Vehicle ].each do |model|
      assert_equal 0, model.count, model.name
    end
  end

  test "customer only sees own deliveries even without a Rails scope" do
    DatabaseAccess.with_context(role: "customer", user_id: @client.id) do
      assert_equal [ @client.customer.id ], Customer.pluck(:id)
      assert_equal [ @run.id ], RouteRun.pluck(:id)
      assert_equal [ @stop.id ], ScheduledStop.pluck(:id)
      assert_equal 0, Route.count
      assert_equal 0, ScheduledStop.where(id: @other_stop.id).update_all(requested_quantity: 99)
    end
    assert_equal 0, ScheduledStop.count, "Context must not leak after returning the connection"
  end

  test "distributor can update own status but not reassign deliveries" do
    DatabaseAccess.with_context(role: "distributor", user_id: @distributor_id) do
      assert_equal [ @run.id ], RouteRun.pluck(:id)
      assert_equal [ @stop.id ], ScheduledStop.pluck(:id)
      assert_equal 1, ScheduledStop.where(id: @stop.id).update_all(status: "cancelled")
      assert_equal 0, ScheduledStop.where(id: @other_stop.id).update_all(status: "cancelled")
      assert_forbidden { ScheduledStop.where(id: @stop.id).update_all(route_run_id: @other_run.id) }
      assert_forbidden { User.where(id: @distributor_id).update_all(role: "admin") }
    end
  end

  test "customer cannot self approve and baker is read only" do
    DatabaseAccess.with_context(role: "customer", user_id: @client.id) do
      assert_forbidden { ScheduledStop.where(id: @stop.id).update_all(approval_status: "approved", approved_quantity: 100) }
      assert_equal 0, Customer.where(id: @client.customer.id).update_all(active: false)
    end
    DatabaseAccess.with_context(role: "baker", user_id: 123) do
      assert_equal 2, ScheduledStop.count
      assert_equal 0, ScheduledStop.update_all(status: "cancelled")
      assert_equal 0, User.count
    end
  end

  test "customer request respects the database deadline and resets approval" do
    before_cutoff = @connection.select_value("SELECT EXTRACT(HOUR FROM CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Lisbon') < 23")
    DatabaseAccess.with_context(role: "customer", user_id: @client.id) do
      if before_cutoff
        assert @stop.request_bread(10), @stop.errors.full_messages.join(", ")
        assert_equal "pending", @stop.reload.approval_status
      else
        assert_not @stop.request_bread(10)
        assert_forbidden { ScheduledStop.where(id: @stop.id).update_all(requested_quantity: 10, approval_status: "pending") }
      end
    end
    if before_cutoff
      DatabaseAccess.with_context(role: "admin", user_id: @admin_id) { assert @stop.decide!("approved") }
      DatabaseAccess.with_context(role: "customer", user_id: @client.id) do
        assert @stop.request_bread(12)
        assert_nil @stop.reload.approved_quantity
        assert_equal "pending", @stop.approval_status
      end
    end
  end

  test "admin can manage records and exception restores prior context" do
    assert_raises(RuntimeError) do
      DatabaseAccess.with_context(role: "admin", user_id: @admin_id) do
        assert_equal 2, ScheduledStop.count
        assert_equal 1, Customer.where(id: customers(:two).id).update_all(active: false)
        raise "abort"
      end
    end
    assert_equal 0, ScheduledStop.count
  end

  private

  def assert_forbidden
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.transaction(requires_new: true) { yield }
    end
  end
end
