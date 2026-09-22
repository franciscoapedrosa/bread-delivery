class ScheduledStop < ApplicationRecord
  encrypts :address, :rejection_reason
  belongs_to :route_run
  belongs_to :customer
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :address, presence: true
  validates :requested_quantity, :approved_quantity,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000 }, allow_nil: true
  validates :status, inclusion: { in: %w[pending delivered cancelled] }
  validates :approval_status, inclusion: { in: %w[awaiting_request pending approved rejected] }
  validate :delivery_needs_approval
  validate :rejected_request_needs_reason
  scope :ordered, -> { order(:position, :id) }
  scope :for_tomorrow, -> { joins(:route_run).where(route_runs: { delivery_date: Date.tomorrow, removed: false }).where(status: "pending") }

  def self.awaiting_tomorrow_request
    return none if Time.current >= Date.current.in_time_zone("Europe/Lisbon").change(hour: 23)

    for_tomorrow.joins(:customer).where(customers: { active: true }, approval_status: "awaiting_request")
  end

  def open_for_request?
    customer.active? && status == "pending" && !route_run.removed? && route_run.delivery_date == Date.tomorrow && Time.current < route_run.cutoff
  end

  def request_bread(quantity)
    with_lock do
      errors.clear
      unless open_for_request?
        errors.add(:base, "O prazo terminou ou esta entrega já está fechada.")
        return false
      end
      assign_attributes(requested_quantity: quantity, approved_quantity: nil, approval_status: "pending", rejection_reason: nil)
      errors.add(:base, "Indique a quantidade de pão.") if requested_quantity.nil?
      return false if errors.any?

      save
    end
  end

  def decide!(decision, expected_quantity: requested_quantity, rejection_reason: nil)
    with_lock do
      unless status == "pending" && approval_status == "pending" && requested_quantity.present?
        errors.add(:base, "Este pedido já foi tratado ou ainda não tem quantidade.")
        return false
      end
      if requested_quantity.to_s != expected_quantity.to_s
        errors.add(:base, "O cliente alterou a quantidade. Consulte o pedido atualizado antes de aprovar.")
        return false
      end
      reason = rejection_reason.to_s.strip
      if decision == "rejected" && reason.blank?
        errors.add(:base, "Indique o motivo da recusa.")
        return false
      end
      update(
        approval_status: decision,
        approved_quantity: decision == "approved" ? requested_quantity : nil,
        rejection_reason: decision == "rejected" ? reason : nil
      )
    end
  end

  private

  def delivery_needs_approval
    if status == "delivered" && (approval_status != "approved" || approved_quantity.to_i <= 0)
      errors.add(:base, "É necessário aprovar uma quantidade de pão antes de marcar como entregue.")
    end
  end

  def rejected_request_needs_reason
    return unless new_record? || will_save_change_to_approval_status? || will_save_change_to_rejection_reason?

    errors.add(:base, "Indique o motivo da recusa.") if approval_status == "rejected" && rejection_reason.blank?
  end
end
