class ScheduledStop < ApplicationRecord
  belongs_to :route_run
  belongs_to :customer
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :address, presence: true
  validates :requested_quantity, :approved_quantity,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000 }, allow_nil: true
  validates :status, inclusion: { in: %w[pending delivered cancelled] }
  validates :approval_status, inclusion: { in: %w[awaiting_request pending approved rejected] }
  validate :delivery_needs_approval
  scope :ordered, -> { order(:position, :id) }

  def open_for_request?
    customer.active? && status == "pending" && Time.current < route_run.cutoff
  end

  def request_bread(quantity)
    with_lock do
      errors.clear
      unless open_for_request?
        errors.add(:base, "O prazo terminou ou esta entrega já está fechada.")
        return false
      end
      assign_attributes(requested_quantity: quantity, approved_quantity: nil, approval_status: "pending")
      errors.add(:base, "Indique a quantidade de pão.") if requested_quantity.nil?
      return false if errors.any?

      save
    end
  end

  def decide!(decision, expected_quantity: requested_quantity)
    with_lock do
      unless status == "pending" && approval_status == "pending" && requested_quantity.present?
        errors.add(:base, "Este pedido já foi tratado ou ainda não tem quantidade.")
        return false
      end
      if requested_quantity.to_s != expected_quantity.to_s
        errors.add(:base, "O cliente alterou a quantidade. Consulte o pedido atualizado antes de aprovar.")
        return false
      end
      update(approval_status: decision, approved_quantity: decision == "approved" ? requested_quantity : nil)
    end
  end

  private

  def delivery_needs_approval
    if status == "delivered" && (approval_status != "approved" || approved_quantity.to_i <= 0)
      errors.add(:base, "É necessário aprovar uma quantidade de pão antes de marcar como entregue.")
    end
  end
end
