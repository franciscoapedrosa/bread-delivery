class AddRejectionReasonToScheduledStops < ActiveRecord::Migration[8.1]
  def change
    add_column :scheduled_stops, :rejection_reason, :text
  end
end
