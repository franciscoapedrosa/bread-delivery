class Route < ApplicationRecord
  has_many :deliveries, dependent: :destroy
  has_many :customers, through: :deliveries

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
