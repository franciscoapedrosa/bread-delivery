require "test_helper"

class WeeklyRoutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    sign_in users(:admin)
  end

  test "admin creates and edits recurrence while preserving submitted orders" do
    get new_weekly_route_path
    assert_response :success
    post weekly_routes_path, params: { weekly_route: { route_id: routes(:one).id, distributor_id: users(:distributor).id, days: "all", starts_on: Date.current, position: 1 } }
    assert_redirected_to route_runs_path
    schedule = WeeklyRoute.last
    run = RouteRun.find_by!(weekly_route_id: schedule.id, delivery_date: Date.tomorrow + 1)
    stop = run.scheduled_stops.first
    stop.update!(requested_quantity: 10, approval_status: "pending")
    get edit_weekly_route_path(schedule)
    assert_response :success
    patch weekly_route_path(schedule), params: { weekly_route: { days: ((run.delivery_date.wday + 1) % 7).to_s, position: 2 } }
    assert_redirected_to route_runs_path
    assert_equal 10, stop.reload.requested_quantity
    assert_equal "pending", stop.approval_status
    assert RouteRun.exists?(run.id)
    get route_runs_path
    assert_response :success
    assert_select "h1", "Agenda semanal"
  end

  test "removing one occurrence keeps recurrence and removing all stops it" do
    schedule = WeeklyRoute.create!(route: routes(:one), distributor: users(:distributor), days: "all", starts_on: Date.current, position: 1)
    WeeklyRoute.materialize_through!(Date.current + 7)
    run = RouteRun.find_by!(weekly_route_id: schedule.id, delivery_date: Date.tomorrow)
    stop = run.scheduled_stops.first

    delete route_run_path(run), params: { scope: "one" }
    assert_response :redirect
    assert run.reload.removed?
    assert_equal "cancelled", stop.reload.status
    WeeklyRoute.materialize_through!(Date.current + 7)
    assert_equal 1, RouteRun.where(route_id: run.route_id, delivery_date: run.delivery_date).count
    assert WeeklyRoute.exists?(schedule.id)

    other_run = RouteRun.find_by!(weekly_route_id: schedule.id, delivery_date: Date.tomorrow + 1)
    delete route_run_path(other_run), params: { scope: "all" }
    assert_response :redirect
    assert_not WeeklyRoute.exists?(schedule.id)
    assert_not RouteRun.where(route_id: run.route_id, delivery_date: Date.current.., removed: false).exists?
    assert_no_difference "RouteRun.count" do
      WeeklyRoute.materialize_through!(Date.current + 30)
    end
  end

  test "distributor cannot remove a route" do
    run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow, position: 1)
    sign_in users(:distributor)
    delete route_run_path(run), params: { scope: "all" }
    assert_redirected_to authenticated_root_path
    assert_not run.reload.removed?
  end

  test "admin can remove a delivery with a legacy rejection without a reason" do
    run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow, position: 1)
    stop = run.scheduled_stops.first
    stop.update_columns(approval_status: "rejected", requested_quantity: 10, rejection_reason: nil)

    delete route_run_path(run), params: { scope: "one" }

    assert_redirected_to route_runs_path
    assert run.reload.removed?
    assert_equal "cancelled", stop.reload.status
    assert_equal "rejected", stop.approval_status
    assert_nil stop.rejection_reason
  end
end
