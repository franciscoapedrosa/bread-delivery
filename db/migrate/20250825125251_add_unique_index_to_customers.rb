class AddUniqueIndexToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_index :customers, [ :name, :address, :bread_quantity ], unique: true
  end
end
