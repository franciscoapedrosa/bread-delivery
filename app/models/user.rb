class User < ApplicationRecord
  encrypts :email, deterministic: true, downcase: true
  ROLES = %w[admin distributor customer baker].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable, :lockable

  has_many :deliveries, foreign_key: :distributor_id, inverse_of: :distributor, dependent: :destroy
  has_many :route_runs, foreign_key: :distributor_id, dependent: :restrict_with_error
  has_one :customer, dependent: :restrict_with_error
  has_many :vehicles, foreign_key: :distributor_id, dependent: :nullify
  accepts_nested_attributes_for :customer
  validate :customer_profile_required
  validate :preserve_assigned_role

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :role, uniqueness: { message: "já tem uma conta de padeiro. Use a conta partilhada existente." }, if: :baker?

  def baker?
    role == "baker"
  end

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
    return if persisted? && !will_save_change_to_role?

    errors.add(:base, "Preencha o nome e a morada do cliente.") if customer? && customer.nil?
  end

  def preserve_assigned_role
    return unless persisted? && will_save_change_to_role?

    if customer.present? || route_runs.exists? || deliveries.exists? || vehicles.exists?
      errors.add(:base, "Esta conta já tem um cliente ou entregas associados. Mantenha a sua função.")
    end
  end
end
