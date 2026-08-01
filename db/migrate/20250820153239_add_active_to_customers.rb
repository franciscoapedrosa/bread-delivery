class AddActiveToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :active, :boolean, default: true
  end
end
