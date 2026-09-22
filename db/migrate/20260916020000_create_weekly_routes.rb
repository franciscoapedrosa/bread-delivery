class CreateWeeklyRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :weekly_routes do |t|
      t.references :route, null: false, foreign_key: true, index: { unique: true }
      t.references :distributor, null: false, foreign_key: { to_table: :users }
      t.string :days, null: false
      t.integer :position, default: 1, null: false
      t.date :starts_on, null: false
      t.timestamps
    end
  end
end
