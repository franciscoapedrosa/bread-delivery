class Customer < ApplicationRecord
  has_many :deliveries, dependent: :destroy
  belongs_to :user, optional: true
  has_many :route_stops, dependent: :destroy
  has_many :routes, through: :route_stops
  has_many :scheduled_stops, dependent: :restrict_with_error

  validates :name, :address, :bread_quantity, presence: true
  validates :bread_quantity, numericality: { greater_than: 0 }

  validates :name, uniqueness: {
    scope: %i[address bread_quantity],
    message: "already exists with the same address and bread quantity"
  }


  scope :active, -> { where(active: true) }

  # When deactivated (active: true -> false), delete his deliveries
  before_update :destroy_deliveries_if_deactivating

  private

  def destroy_deliveries_if_deactivating
    # ativo -> inativo?
    if active_change_to_be_saved == [ true, false ]
      deliveries.destroy_all
    end
  end
end
