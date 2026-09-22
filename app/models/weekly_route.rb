class WeeklyRoute < ApplicationRecord
  OPTIONS = [ [ "Todos os dias", "all" ], [ "Dias úteis (segunda a sexta)", "weekdays" ], [ "Segunda-feira", "1" ], [ "Terça-feira", "2" ], [ "Quarta-feira", "3" ], [ "Quinta-feira", "4" ], [ "Sexta-feira", "5" ], [ "Sábado", "6" ], [ "Domingo", "0" ] ].freeze
  belongs_to :route
  belongs_to :distributor, class_name: "User"
  validates :route_id, uniqueness: true
  validates :days, inclusion: { in: OPTIONS.map(&:last) }
  validates :starts_on, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate do
    errors.add(:base, "Escolha um distribuidor.") unless distributor&.distributor?
    errors.add(:base, "Adicione clientes ativos à rota.") unless route&.route_stops&.joins(:customer)&.where(customers: { active: true })&.exists?
  end

  def includes_date?(date)
    date >= starts_on && (days == "all" || (days == "weekdays" ? (1..5).cover?(date.wday) : date.wday.to_s == days))
  end

  def self.materialize_through!(last_date)
    find_each do |schedule|
      schedule.with_lock do
        ([ Date.current, schedule.starts_on ].max..last_date).each do |date|
          next unless schedule.includes_date?(date)
          existing = RouteRun.where(route_id: schedule.route_id, delivery_date: date)
          next if existing.where(removed: false).exists?
          next if existing.where(removed: true, weekly_route_id: schedule.id).exists?

          RouteRun.create!(weekly_route_id: schedule.id, route: schedule.route, distributor: schedule.distributor, delivery_date: date, position: schedule.position) if schedule.valid?
        end
      end
    end
  end
end
