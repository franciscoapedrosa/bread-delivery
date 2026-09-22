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
    label = "#{day_name(date.strftime('%A').downcase)}, #{date.strftime('%d/%m/%Y')}"
    [ relative_delivery_day(date), label ].compact.join(" · ")
  end

  def relative_delivery_day(date)
    return "Hoje" if date == Date.current
    "Amanhã" if date == Date.current + 1
  end

  def bread_quantity_summary(stop)
    case stop.approval_status
    when "approved"
      "#{stop.approved_quantity} pães aprovados"
    when "pending"
      "#{stop.requested_quantity} pães — por aprovar"
    when "rejected"
      "Quantidade de pão por pedir (pedido anterior recusado)"
    else
      "Quantidade de pão por pedir"
    end
  end
end
