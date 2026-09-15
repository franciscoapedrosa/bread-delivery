class VehiclesController < ApplicationController
  before_action :require_admin!, except: %i[index show photo]
  before_action :set_vehicle, only: %i[show edit update destroy photo]

  def index
    @vehicles = visible_vehicles.order(:name).includes(:distributor)
  end

  def show
  end

  def new
    @vehicle = Vehicle.new
  end

  def create
    @vehicle = Vehicle.new(vehicle_params)
    if @vehicle.save
      redirect_to @vehicle, notice: "Veículo criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @vehicle.update(vehicle_params)
      redirect_to @vehicle, notice: "Veículo atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vehicle.destroy!
    redirect_to vehicles_path, notice: "Veículo eliminado."
  end

  def photo
    return head :not_found if @vehicle.photo_data.blank?

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data @vehicle.photo_data, type: @vehicle.photo_type, disposition: "inline"
  end

  private

  def visible_vehicles
    return Vehicle.all if current_user.admin?
    return current_user.vehicles if current_user.distributor?

    Vehicle.none
  end

  def set_vehicle
    @vehicle = visible_vehicles.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(:name, :registration, :distributor_id, :photo)
  end
end
