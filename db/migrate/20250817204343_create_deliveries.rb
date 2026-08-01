class CreateDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :deliveries do |t|
      t.references :route, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :distributor, null: false, foreign_key: { to_table: :users }
      t.string :status

      t.timestamps
    end
  end
end
