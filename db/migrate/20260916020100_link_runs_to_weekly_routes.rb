class LinkRunsToWeeklyRoutes < ActiveRecord::Migration[8.1]
  def change
    add_reference :route_runs, :weekly_route, foreign_key: true
  end
end
