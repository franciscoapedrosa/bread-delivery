class BakeryController < ApplicationController
  before_action :authorize_bakery

  def index
    @week = Date.iso8601(params[:week].presence || Date.current.to_s).beginning_of_week
    @stops = ScheduledStop.joins(:route_run).where(route_runs: { delivery_date: @week..@week.end_of_week, removed: false }).where.not(status: "cancelled")
    @totals = @stops.where(approval_status: "approved").group("route_runs.delivery_date").sum(:approved_quantity)
    @waiting = @stops.where(approval_status: %w[awaiting_request pending]).group("route_runs.delivery_date").count
    tomorrow_stops = ScheduledStop.joins(:route_run).where(route_runs: { delivery_date: Date.tomorrow, removed: false }, approval_status: "approved").where.not(status: "cancelled")
    @tomorrow_total = tomorrow_stops.sum(:approved_quantity)
    tomorrow_totals = tomorrow_stops.group(:customer_id).sum(:approved_quantity)
    daily_totals = @stops.where(approval_status: "approved").group("route_runs.delivery_date", :customer_id).sum(:approved_quantity)
    names = Customer.where(id: tomorrow_totals.keys | daily_totals.keys.map(&:last)).to_h { |customer| [ customer.id, customer.name ] }
    @tomorrow_customers = tomorrow_totals.map { |id, quantity| [ [ id, names.fetch(id) ], quantity ] }.sort_by { |(id, name), quantity| name.downcase }
    @daily_customers = daily_totals.map { |(date, id), quantity| [ [ date, id, names.fetch(id) ], quantity ] }.sort_by { |(date, id, name), quantity| name.downcase }
  rescue Date::Error
    redirect_to bakery_path, alert: "Data inválida."
  end

  private

  def authorize_bakery
    deny_access! unless current_user.admin? || current_user.baker?
  end
end
