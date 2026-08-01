module ApplicationHelper
  DAYS_PT = {
    "monday" => "Segunda-feira",
    "tuesday" => "Terça-feira",
    "wednesday" => "Quarta-feira",
    "thursday" => "Quinta-feira",
    "friday" => "Sexta-feira",
    "saturday" => "Sábado",
    "sunday" => "Domingo"
  }.freeze

  STATUS_PT = {
    "pending" => "Pendente",
    "delivered" => "Entregue",
    "cancelled" => "Cancelada"
  }.freeze

  def day_name(day)
    DAYS_PT.fetch(day, day.to_s.humanize)
  end

  def delivery_status(status)
    STATUS_PT.fetch(status, status.to_s.humanize)
  end

  def role_name(role)
    role == "admin" ? "Administrador" : "Distribuidor"
  end
end
