class RoutesController < ApplicationController
  before_action :set_route, only: %i[show edit update destroy]
  before_action :require_admin!, except: :index

  def index
    if current_user.admin?
      @routes = Route.all
    else
      @routes = Route.joins(:deliveries).where(deliveries: { distributor_id: current_user.id }).distinct
    end
    order = %w[monday tuesday wednesday thursday friday saturday sunday]
    @routes_by_day = @routes.group_by do |route|
      route.deliveries.find_by(distributor_id: current_user.id)&.day_of_week
    end.compact

    @routes_by_day = @routes_by_day.sort_by { |day, _| order.index(day) || 0 }.to_h
  end

  def show
  end

  def new
    @route = Route.new
  end

  def edit
  end

  def create
    @route = Route.new(route_params)
    if @route.save
      redirect_to @route, notice: "Route was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @route.update(route_params)
      redirect_to @route, notice: "Route was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @route.destroy
      redirect_to routes_url, notice: "Route was successfully deleted."
    else
      redirect_to routes_url, alert: @route.errors.full_messages.to_sentence
    end
  end

  private

  def set_route
    @route = Route.find(params[:id])
  end

  def route_params
    params.require(:route).permit(:name)
  end
end
