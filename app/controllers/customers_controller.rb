class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy deactivate activate]
  before_action :require_admin!, except: :my_customers

  def my_customers
    unless current_user.distributor?
      redirect_to authenticated_root_path, alert: "Acesso negado."
      return
    end

    deliveries = Delivery.includes(:customer).where(distributor_id: current_user.id)
    @customers = deliveries.map(&:customer).uniq.sort_by(&:name)

    order = %w[monday tuesday wednesday thursday friday saturday sunday]
    @days_by_customer = deliveries.group_by(&:customer_id).transform_values { |ds| ds.map(&:day_of_week).uniq.sort_by { |d| order.index(d) || 0 } }
  end

  def index
    @active_customers   = Customer.active.order(:name)
    @inactive_customers = Customer.where(active: false).order(:name)
  end

  def show
  end

  def new
    @customer = Customer.new
  end

  def edit
  end

  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      redirect_to @customer, notice: "Cliente criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Cliente atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @customer.destroy
      redirect_to customers_path, notice: "Cliente eliminado permanentemente."
    else
      redirect_to customers_path, alert: @customer.errors.full_messages.to_sentence
    end
  end

  def deactivate
    if @customer.update(active: false)
      redirect_to customers_path, notice: "Cliente desativado com sucesso."
    else
      redirect_to customers_path, alert: "Não foi possível desativar o cliente."
    end
  end

  def activate
    if @customer.update(active: true)
      redirect_to customers_path, notice: "Cliente reativado com sucesso."
    else
      redirect_to customers_path, alert: "Não foi possível reativar o cliente."
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :address, :bread_quantity)
  end
end
