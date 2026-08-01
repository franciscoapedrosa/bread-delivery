class RemoveDayOfWeekFromRoutes < ActiveRecord::Migration[8.0]
  def change
    remove_column :routes, :day_of_week, :string
  end
end
