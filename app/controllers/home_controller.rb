class HomeController < ApplicationController
  before_action :authenticate_user! # Ensure user is authenticated
  def index
    if current_user.admin?
      @unsubmitted_bread_requests = ScheduledStop.awaiting_tomorrow_request.count
    elsif current_user.customer?
      @customer_request_day_counts = current_user.customer.scheduled_stops.joins(:route_run)
        .where(route_runs: { delivery_date: Date.tomorrow, removed: false })
        .where(status: "pending")
        .where.not(requested_quantity: nil)
        .where(approval_status: %w[pending rejected])
        .group(:approval_status).distinct.count("route_runs.delivery_date")
    end
  end
end
