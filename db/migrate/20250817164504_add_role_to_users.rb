class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :integer, default: 0, null: false # Adding role column to users table, each user will start as distributer
  end
end
