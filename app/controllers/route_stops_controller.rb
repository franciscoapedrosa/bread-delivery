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
