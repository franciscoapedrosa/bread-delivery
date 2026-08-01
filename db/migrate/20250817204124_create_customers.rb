class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :address
      t.integer :bread_quantity

      t.timestamps
    end
  end
end
