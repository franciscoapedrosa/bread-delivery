class RouteRunsController < ApplicationController
  before_action :require_admin!, only: %i[new create update]
  before_action :set_run, only: %i[show update]

  def index
    @week = Date.iso8601(params[:week].presence || Date.current.to_s).beginning_of_week
    @runs = visible_runs.where(delivery_date: @week..@week.end_of_week)
      .includes(:route, :distributor, scheduled_stops: :customer).ordered
  rescue Date::Error
    redirect_to route_runs_path, alert: "Data inválida."
  end

  def show
    @stops = @run.scheduled_stops.includes(:customer).ordered
  end

  def new
    @run = RouteRun.new(delivery_date: Date.tomorrow, position: 1, route_id: params[:route_id])
  end

  def create
    @run = RouteRun.new(run_params)
    if @run.save
      redirect_to @run, notice: "Entrega marcada. Os clientes já podem pedir o pão para este dia."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @run.errors.add(:base, "Esta rota já está marcada para esse dia.")
    render :new, status: :unprocessable_entity
  end

  def update
    # Date and route remain fixed: changing them would change existing order deadlines.
    if @run.update(params.require(:route_run).permit(:distributor_id, :position))
      redirect_to @run, notice: "Distribuidor e ordem atualizados."
    else
      @stops = @run.scheduled_stops.includes(:customer).ordered
      render :show, status: :unprocessable_entity
    end
  end

  private

  def visible_runs
    return RouteRun.all if current_user.admin?
    return current_user.route_runs if current_user.distributor?

    RouteRun.none
  end

  def set_run
    @run = visible_runs.find(params[:id])
  end

  def run_params
    params.require(:route_run).permit(:route_id, :distributor_id, :delivery_date, :position)
  end
end
