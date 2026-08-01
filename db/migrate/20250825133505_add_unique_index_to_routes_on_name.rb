class AddUniqueIndexToRoutesOnName < ActiveRecord::Migration[8.0]
  def change
    add_index :routes, "lower(name)", unique: true, name: "index_routes_on_lower_name"
  end
end
