class BakeryController < ApplicationController
  before_action :authorize_bakery

  def index
    @week = Date.iso8601(params[:week].presence || Date.current.to_s).beginning_of_week
    @stops = ScheduledStop.joins(:route_run).where(route_runs: { delivery_date: @week..@week.end_of_week }).where.not(status: "cancelled")
    @totals = @stops.where(approval_status: "approved").group("route_runs.delivery_date").sum(:approved_quantity)
    @waiting = @stops.where(approval_status: %w[awaiting_request pending]).group("route_runs.delivery_date").count
    @tomorrow_total = ScheduledStop.joins(:route_run).where(route_runs: { delivery_date: Date.tomorrow }, approval_status: "approved").where.not(status: "cancelled").sum(:approved_quantity)
  rescue Date::Error
    redirect_to bakery_path, alert: "Data inválida."
  end

  private

  def authorize_bakery
    redirect_to authenticated_root_path, alert: "Acesso negado." unless current_user.admin? || current_user.baker?
  end
end
