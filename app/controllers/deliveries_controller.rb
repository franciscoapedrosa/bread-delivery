class DeliveriesController < ApplicationController
  before_action :deny_customer
  before_action :set_delivery, only: %i[show edit update destroy]
  before_action :authorize_delivery!, only: %i[show edit update destroy]
  before_action :require_admin!, only: %i[new create destroy_week]


def index
  if current_user.admin?
    @deliveries = Delivery.includes(:route, :customer, :distributor).all
  else
    @deliveries = Delivery.includes(:route, :customer).where(distributor_id: current_user.id)
  end

  @deliveries_by_day = @deliveries.group_by(&:day_of_week)
  order = %w[monday tuesday wednesday thursday friday saturday sunday]
  @deliveries_by_day = @deliveries_by_day.sort_by { |day, _| order.index(day) || 0 }.to_h

  if current_user.admin?
      # weekly total across all days
      @weekly_total_admin = @deliveries.sum { |d| d.customer.bread_quantity.to_i }

      # daily totals for admin view
      @day_totals_admin = Hash[
        order.map { |day|
          [ day, (@deliveries_by_day[day] || []).sum { |d| d.customer.bread_quantity.to_i } ]
        }
      ]

      # totals by distributor for admin view
      @totals_by_distributor = @deliveries
        .group_by(&:distributor)
        .map { |user, ds| [ user, ds.sum { |d| d.customer.bread_quantity.to_i } ] }
        .sort_by { |(_user, total)| -total }
  else
        @day_totals = @deliveries_by_day.transform_values { |ds|
      ds.sum { |d| d.customer.bread_quantity.to_i }
    }
  end
end


  def show
  end

  def new
    @delivery = Delivery.new
  end

  def edit
  end

  def create
    @delivery = Delivery.new(delivery_params)
    if @delivery.save
      redirect_to @delivery, notice: "Entrega criada com sucesso."
    else
      flash.now[:alert] = @delivery.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
      @delivery ||= Delivery.new(delivery_params)
      @delivery.errors.add(:base, "Já existe uma entrega para esta rota, cliente, distribuidor e dia.")
      flash.now[:alert] = @delivery.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
  end

  def update
    if @delivery.update(delivery_params)
      redirect_to @delivery, notice: "Entrega atualizada com sucesso."
    else
      flash.now[:alert] = @delivery.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
      @delivery ||= Delivery.new(delivery_params)
      @delivery.errors.add(:base, "Já existe uma entrega para esta rota, cliente, distribuidor e dia.")
      flash.now[:alert] = @delivery.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
  end

  def destroy
    @delivery.destroy
    redirect_to deliveries_url, notice: "Entrega eliminada com sucesso."
  end

  def reset_week
    scope = current_user.admin? ? Delivery.all : Delivery.where(distributor_id: current_user.id)
    scope = scope.where(day_of_week: params[:day]) if params[:day].present?
    updated = scope.update_all(status: "pending", updated_at: Time.current)
    redirect_to deliveries_path, notice: "Semana reposta: #{updated} entregas ficaram pendentes."
  end

  def destroy_week
    scope = Delivery.all
    scope = scope.where(day_of_week: params[:day]) if params[:day].present?
    deleted = scope.delete_all
    redirect_to deliveries_path, notice: "Semana eliminada: #{deleted} entregas removidas."
  end


  private

  def deny_customer
    deny_access! unless current_user.admin? || current_user.distributor?
  end

  def set_delivery
    @delivery = Delivery.find(params[:id])
  end

  def delivery_params
    if current_user.admin?
      params.require(:delivery).permit(:route_id, :customer_id, :distributor_id, :day_of_week, :status)
    else
      params.require(:delivery).permit(:status)
    end
  end

  def authorize_delivery!
    return if current_user.admin?

    return if %w[show edit update].include?(action_name) && @delivery.distributor_id == current_user.id

    redirect_to deliveries_path, alert: "Operação não permitida."
  end
end
