class AddAuthenticationProtection < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
    create_table :login_throttles do |t|
      t.string :key, null: false
      t.integer :attempts, default: 0, null: false
      t.datetime :expires_at, null: false
      t.index :key, unique: true
      t.index :expires_at
    end
  end
end
