class AddDayOfWeekToDeliveries < ActiveRecord::Migration[8.0]
  def change
    add_column :deliveries, :day_of_week, :string
  end
end
