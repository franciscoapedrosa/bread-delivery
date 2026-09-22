class RouteRun < ApplicationRecord
  belongs_to :route
  belongs_to :distributor, class_name: "User"
  has_many :scheduled_stops, dependent: :destroy
  validates :delivery_date, presence: true
  validates :delivery_date, uniqueness: { scope: :route_id, conditions: -> { where(removed: false) } }, unless: :removed?
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :valid_distributor
  validate :future_date, on: :create
  validate :route_has_customers, on: :create
  after_create :copy_stops
  scope :ordered, -> { order(:delivery_date, :position, :id) }

  def cutoff
    delivery_date.in_time_zone("Europe/Lisbon").advance(days: -1).change(hour: 23)
  end

  def total_bread
    scheduled_stops.reject { |stop| stop.status == "cancelled" }.sum { |stop| stop.approved_quantity.to_i }
  end

  private

  def valid_distributor
    errors.add(:base, "Escolha um distribuidor.") unless distributor&.distributor?
  end

  def future_date
    errors.add(:base, "Escolha uma data de hoje em diante.") if delivery_date && delivery_date < Date.current
  end

  def route_has_customers
    unless route&.route_stops&.joins(:customer)&.where(customers: { active: true })&.exists?
      errors.add(:base, "Adicione clientes ativos à rota antes de marcar a entrega.")
    end
  end

  def copy_stops
    route.route_stops.ordered.includes(:customer).each do |stop|
      next unless stop.customer.active?

      scheduled_stops.create!(customer: stop.customer, position: stop.position, address: stop.customer.address)
    end
  end
end
