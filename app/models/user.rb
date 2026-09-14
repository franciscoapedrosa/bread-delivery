class User < ApplicationRecord
  ROLES = %w[admin distributor customer].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  has_many :deliveries, foreign_key: :distributor_id, inverse_of: :distributor, dependent: :destroy
  has_many :route_runs, foreign_key: :distributor_id, dependent: :restrict_with_error
  has_one :customer, dependent: :restrict_with_error
  accepts_nested_attributes_for :customer
  validate :customer_profile_required
  validate :preserve_assigned_role

  validates :role, presence: true, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def distributor?
    role == "distributor"
  end

  def customer?
    role == "customer"
  end

  private

  def customer_profile_required
    errors.add(:base, "Preencha o nome e a morada do cliente.") if customer? && customer.nil?
  end

  def preserve_assigned_role
    return unless persisted? && will_save_change_to_role?

    if customer.present? || route_runs.exists? || deliveries.exists?
      errors.add(:base, "Esta conta já tem um cliente ou entregas associados. Mantenha a sua função.")
    end
  end
end
