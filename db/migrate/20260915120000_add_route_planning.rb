class AddRoutePlanning < ActiveRecord::Migration[8.0]
  def up
    add_reference :customers, :user, foreign_key: true, index: { unique: true }
    create_table :route_stops do |t|
      t.references :route, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.integer :position, null: false, default: 1
      t.timestamps
    end
    add_index :route_stops, [ :route_id, :customer_id ], unique: true
    create_table :route_runs do |t|
      t.references :route, null: false, foreign_key: true
      t.references :distributor, null: false, foreign_key: { to_table: :users }
      t.date :delivery_date, null: false
      t.integer :position, null: false, default: 1
      t.timestamps
    end
    add_index :route_runs, [ :route_id, :delivery_date ], unique: true
    create_table :scheduled_stops do |t|
      t.references :route_run, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :address, null: false
      t.integer :requested_quantity
      t.integer :approved_quantity
      t.string :approval_status, null: false, default: "awaiting_request"
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :scheduled_stops, [ :route_run_id, :customer_id ], unique: true
    # Preserve existing customer/route associations without inventing delivery dates.
    execute <<~SQL
      INSERT INTO route_stops (route_id, customer_id, position, created_at, updated_at)
      SELECT route_id, customer_id, MIN(id), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM deliveries GROUP BY route_id, customer_id
    SQL
  end

  def down
    drop_table :scheduled_stops
    drop_table :route_runs
    drop_table :route_stops
    remove_reference :customers, :user
  end
end
