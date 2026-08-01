class Delivery < ApplicationRecord
  belongs_to :route
  belongs_to :customer
  belongs_to :distributor, class_name: "User"

  before_validation :normalize_day

  validates :status, presence: true, inclusion: { in: %w[pending delivered cancelled] }
  validates :day_of_week, presence: true, inclusion: { in: %w[monday tuesday wednesday thursday friday saturday sunday] }

  validates :customer_id, uniqueness: {
    scope: [ :route_id, :distributor_id, :day_of_week ],
    message: "already has a delivery for this route/distributor"
  }

  private

  def normalize_day
    self.day_of_week = day_of_week.to_s.downcase.strip if day_of_week.present?
  end
end
