class User < ApplicationRecord
  ROLES = %w[admin distributor].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  has_many :deliveries, foreign_key: :distributor_id, inverse_of: :distributor, dependent: :destroy

  validates :role, presence: true, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def distributor?
    role == "distributor"
  end
end
