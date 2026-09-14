class ScheduledStopsController < ApplicationController
  before_action :require_admin!, only: %i[approve reject]

  def index
    if current_user.admin?
      @stops = ScheduledStop.where(approval_status: "pending")
    elsif current_user.customer?
      @stops = current_user.customer.scheduled_stops.joins(:route_run)
        .where(route_runs: { delivery_date: Date.current.. })
    else
      redirect_to route_runs_path
      return
    end
    @stops = @stops.includes(:customer, route_run: :route).joins(:route_run)
      .order("route_runs.delivery_date", :position, :id)
  end

  def update
    if current_user.customer?
      @stop = current_user.customer.scheduled_stops.find(params[:id])
      saved = @stop.request_bread(params.require(:scheduled_stop)[:requested_quantity])
      destination = scheduled_stops_path
    else
      scope = current_user.admin? ? ScheduledStop.all : ScheduledStop.joins(:route_run).where(route_runs: { distributor_id: current_user.id })
      @stop = scope.find(params[:id])
      permitted = current_user.admin? ? %i[status position address] : %i[status]
      saved = @stop.with_lock { @stop.update(params.require(:scheduled_stop).permit(*permitted)) }
      destination = route_run_path(@stop.route_run)
    end
    redirect_to destination, **(saved ? { notice: "Guardado com sucesso." } : { alert: @stop.errors.full_messages.to_sentence })
  end

  def approve
    decide("approved")
  end

  def reject
    decide("rejected")
  end

  private

  def decide(decision)
    stop = ScheduledStop.find(params[:id])
    saved = stop.decide!(decision, expected_quantity: params.require(:requested_quantity))
    redirect_to scheduled_stops_path, **(saved ? { notice: "Pedido #{decision == 'approved' ? 'aprovado' : 'recusado'}." } : { alert: stop.errors.full_messages.to_sentence })
  end
end
