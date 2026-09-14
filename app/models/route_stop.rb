class RouteStop < ApplicationRecord
  belongs_to :route
  belongs_to :customer
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :customer_id, uniqueness: { scope: :route_id }
  scope :ordered, -> { order(:position, :id) }
end
