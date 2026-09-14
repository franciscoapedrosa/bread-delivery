class Route < ApplicationRecord
  has_many :deliveries, dependent: :destroy
  has_many :route_stops, dependent: :destroy
  has_many :customers, through: :route_stops
  has_many :route_runs, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
