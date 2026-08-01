class AddRequiredDefaults < ActiveRecord::Migration[8.0]
  def up
    User.where(role: nil).update_all(role: "distributor")
    Customer.where(active: nil).update_all(active: true)
    Delivery.where(status: nil).update_all(status: "pending")

    change_column_default :users, :role, from: nil, to: "distributor"
    change_column_null :users, :role, false
    change_column_null :customers, :active, false
    change_column_null :deliveries, :status, false
    change_column_null :deliveries, :day_of_week, false
  end

  def down
    change_column_null :deliveries, :day_of_week, true
    change_column_null :deliveries, :status, true
    change_column_null :customers, :active, true
    change_column_null :users, :role, true
    change_column_default :users, :role, from: "distributor", to: nil
  end
end
