class RouteStopsController < ApplicationController
  before_action :require_admin!
  before_action :set_route

  def create
    stop = @route.route_stops.new(stop_params)
    if stop.save
      redirect_to @route, notice: "Cliente adicionado à rota."
    else
      redirect_to @route, alert: stop.errors.full_messages.to_sentence
    end
  end

  def update
    stop = @route.route_stops.find(params[:id])
    if params[:direction].present?
      unless %w[up down].include?(params[:direction])
        head :unprocessable_entity
        return
      end
      @route.with_lock do
        stops = @route.route_stops.ordered.to_a
        index = stops.index { |item| item.id == stop.id }
        target = index + (params[:direction] == "up" ? -1 : 1)
        if target.between?(0, stops.length - 1)
          stops[index], stops[target] = stops[target], stops[index]
          stops.each_with_index { |item, position| item.update!(position: position + 1) }
        end
      end
      redirect_to route_path(@route, anchor: "route-stop-#{stop.id}"), notice: "Ordem atualizada.", status: :see_other
      return
    end
    if stop.update(params.require(:route_stop).permit(:position))
      redirect_to @route, notice: "Ordem atualizada."
    else
      redirect_to @route, alert: stop.errors.full_messages.to_sentence
    end
  end

  def destroy
    @route.route_stops.find(params[:id]).destroy!
    redirect_to @route, notice: "Cliente retirado desta rota. As entregas já marcadas mantêm o seu percurso."
  end

  private

  def set_route
    @route = Route.find(params[:route_id])
  end

  def stop_params
    params.require(:route_stop).permit(:customer_id, :position)
  end
end
