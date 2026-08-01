class UpdateUniqueIndexOnDeliveries < ActiveRecord::Migration[8.0]
  def change
    # removes the last index based on the triplo
    remove_index :deliveries, name: "idx_unique_delivery_triple"

    # adds a new index based on the quadruplo
    add_index :deliveries,
              [ :route_id, :customer_id, :distributor_id, :day_of_week ],
              unique: true,
              name: "idx_unique_delivery_quad"
  end
end
