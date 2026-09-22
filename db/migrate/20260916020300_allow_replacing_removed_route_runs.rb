class AllowReplacingRemovedRouteRuns < ActiveRecord::Migration[8.1]
  def up
    remove_index :route_runs, name: "index_route_runs_on_route_id_and_delivery_date"
    add_index :route_runs, [ :route_id, :delivery_date ], unique: true,
      where: "removed = FALSE", name: "index_active_route_runs_on_route_and_date"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Removed deliveries may share dates with their replacements."
  end
end
