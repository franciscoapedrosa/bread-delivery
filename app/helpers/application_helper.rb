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
    { "admin" => "Administrador", "distributor" => "Distribuidor", "customer" => "Cliente", "baker" => "Padeiro" }.fetch(role, role)
  end

  def approval_name(status)
    { "awaiting_request" => "Pedido por submeter", "pending" => "Aguarda aprovação", "approved" => "Aprovado", "rejected" => "Recusado" }.fetch(status, status)
  end

  def delivery_date_label(date)
    "#{day_name(date.strftime('%A').downcase)}, #{date.strftime('%d/%m/%Y')}"
  end
end
