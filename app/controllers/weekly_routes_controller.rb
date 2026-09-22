class WeeklyRoutesController < ApplicationController
  before_action :require_admin!

  def new
    @schedule = WeeklyRoute.new(starts_on: Date.current, position: 1, days: "weekdays", route_id: params[:route_id])
  end

  def create
    @schedule = WeeklyRoute.new(schedule_params)
    persist(:new)
  end

  def edit
    @schedule = WeeklyRoute.find(params[:id])
  end

  def update
    @schedule = WeeklyRoute.find(params[:id])
    @schedule.assign_attributes(schedule_params.except(:route_id))
    persist(:edit)
  end

  private

  def persist(template)
    if @schedule.valid?
      WeeklyRoute.transaction do
        @schedule.save!
        # Keep today's work and every delivery with customer input intact.
        RouteRun.where(weekly_route_id: @schedule.id, delivery_date: Date.tomorrow..).find_each do |run|
          next if run.scheduled_stops.where.not(approval_status: "awaiting_request").exists? || run.scheduled_stops.where.not(status: "pending").exists?
          if @schedule.includes_date?(run.delivery_date)
            run.update!(distributor: @schedule.distributor, position: @schedule.position)
          else
            run.destroy!
          end
        end
        WeeklyRoute.materialize_through!(Date.current.end_of_week + 7)
      end
      redirect_to route_runs_path, notice: "Agenda semanal guardada. Entregas com pedidos já submetidos foram preservadas."
    else
      render template, status: :unprocessable_entity
    end
  end

  def schedule_params
    params.require(:weekly_route).permit(:route_id, :distributor_id, :days, :starts_on, :position)
  end
end
