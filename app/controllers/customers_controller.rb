class CustomersController < ApplicationController
  before_action :require_admin!, except: :my_customers
  before_action :set_customer, only: %i[show edit update destroy deactivate activate]
  before_action :set_edit_origin, only: %i[edit update]

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
    @customers = Customer.all.sort_by { |customer| [ customer.active? ? 0 : 1, customer.name.downcase ] }
  end

  def show
    @routes = @customer.routes.order(:name)
    @upcoming_stops = @customer.scheduled_stops.includes(route_run: :route).joins(:route_run)
      .where(route_runs: { delivery_date: Date.current.., removed: false }).order("route_runs.delivery_date")
  end

  def new
    redirect_to new_user_path, notice: "Crie o cliente em Utilizadores, escolhendo a função Cliente."
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
      redirect_to @edit_route.present? ? @edit_back_path : @customer, notice: "Cliente atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @customer.active? || @customer.scheduled_stops.exists? || @customer.user.present?
      redirect_to @customer, alert: "Só é possível eliminar clientes inativos, sem conta associada e sem pedidos ou entregas agendadas."
      return
    end
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

  def set_edit_origin
    @edit_route = @customer.routes.find_by(id: params[:route_id]) if params[:origin] == "route"
    if @edit_route
      @edit_origin = "route"
      @edit_back_path = route_path(@edit_route, anchor: "route-stop-#{@customer.route_stops.find_by(route: @edit_route).id}")
      return
    end
    @edit_origin = params[:origin] == "customer" ? "customer" : "list"
    @edit_back_path = @edit_origin == "customer" ? customer_path(@customer) : customers_path
  end

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :address, :bread_quantity)
  end
end
