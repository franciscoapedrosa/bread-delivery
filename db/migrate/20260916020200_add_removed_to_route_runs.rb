class AddRemovedToRouteRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :route_runs, :removed, :boolean, default: false, null: false
  end
end
