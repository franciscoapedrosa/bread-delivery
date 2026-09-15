class AddVehiclesAndBaker < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.string :name, null: false
      t.string :registration, null: false
      t.references :distributor, foreign_key: { to_table: :users }
      t.binary :photo_data
      t.string :photo_type
      t.timestamps
    end
    add_index :vehicles, :registration, unique: true
    add_index :users, :role, unique: true, where: "role = 'baker'", name: "index_users_single_baker"
  end
end
