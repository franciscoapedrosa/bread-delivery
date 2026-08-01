class AddUniqueIndexToDeliveriesTriple < ActiveRecord::Migration[8.0]
  def change
    add_index :deliveries, [ :route_id, :customer_id, :distributor_id ],
              unique: true, name: "idx_unique_delivery_triple"
  end
end
