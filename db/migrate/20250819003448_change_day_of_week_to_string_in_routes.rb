class ChangeDayOfWeekToStringInRoutes < ActiveRecord::Migration[8.0]
  def up
    change_column :routes, :day_of_week, :string
  end

  def down
    change_column :routes, :day_of_week, :integer
  end
end
