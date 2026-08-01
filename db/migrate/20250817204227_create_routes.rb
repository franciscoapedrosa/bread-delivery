class CreateRoutes < ActiveRecord::Migration[8.0]
  def change
    create_table :routes do |t|
      t.string :name
      t.string :day_of_week

      t.timestamps
    end
  end
end
