class RouteRunsController < ApplicationController
  before_action :require_admin!, only: %i[new create update destroy]
  before_action :set_run, only: %i[show update destroy]
  before_action :set_back_path, only: %i[show update]

  def index
    @week = Date.iso8601(params[:week].presence || Date.current.to_s).beginning_of_week
    return deny_access! unless current_user.admin? || current_user.distributor?
    if @week > (Date.current + 1.year).end_of_week
      redirect_to route_runs_path, alert: "Consulte a agenda até um ano de antecedência."
      return
    end
    DatabaseAccess.with_context(role: "system") { WeeklyRoute.materialize_through!(@week.end_of_week) }
    @runs = visible_runs.where(removed: false, delivery_date: @week..@week.end_of_week)
      .includes(:route, :distributor, scheduled_stops: :customer).ordered
    @runs = @runs.where(delivery_date: Date.current..) if current_user.admin?
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

  def destroy
    if @run.delivery_date < Date.current || !%w[one all].include?(params[:scope])
      redirect_to route_runs_path, alert: "Escolha uma entrega atual ou futura e a opção de remoção."
      return
    end
    RouteRun.transaction do
      if params[:scope] == "all"
        schedule = WeeklyRoute.find_by(route_id: @run.route_id)
        if schedule
          schedule.lock!
          RouteRun.where(weekly_route_id: schedule.id).update_all(weekly_route_id: nil)
          schedule.destroy!
        end
        runs = RouteRun.where(route_id: @run.route_id, delivery_date: Date.current..)
      else
        runs = RouteRun.where(id: @run.id)
      end
      runs.find_each do |run|
        run.with_lock do
          run.update!(removed: true)
          run.scheduled_stops.where(status: "pending").find_each { |stop| stop.update!(status: "cancelled") }
        end
      end
    end
    redirect_to route_runs_path(week: params[:week]), notice: params[:scope] == "all" ? "Rota removida da agenda e repetição semanal desativada." : "Entrega removida apenas nesta data."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to route_runs_path(week: params[:week]), alert: "Não foi possível remover: #{error.record.errors.full_messages.to_sentence}"
  end

  private

  def set_back_path
    @route_runs_back_path = if params[:origin] == "bread_requests" && current_user.admin?
      scheduled_stops_path
    else
      route_runs_path(week: params[:week].presence || @run.delivery_date)
    end
  end

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
