class EncryptPersonalData < ActiveRecord::Migration[8.1]
  FIELDS = { "users" => %w[email], "customers" => %w[name address], "scheduled_stops" => %w[address rejection_reason] }.freeze

  def up
    # Fail before changing any data when the deployment has no encryption keys.
    ActiveRecord::Encryption.encryptor.encrypt("key-check")
    FIELDS.each do |table, fields|
      fields.each do |field|
        options = if table == "users"
          { null: false, default: "" }
        elsif table == "scheduled_stops" && field == "address"
          { null: false }
        else
          {}
        end
        change_column table, field, :text, **options
      end
      model = Class.new(ActiveRecord::Base) do
        self.table_name = table
        fields.each { |field| encrypts field, deterministic: table != "scheduled_stops", downcase: field == "email" }
      end
      select_all("SELECT id, #{fields.join(', ')} FROM #{table}").each do |row|
        updates = fields.filter_map do |field|
          value = row[field]
          next if value.nil? || ActiveRecord::Encryption.encryptor.encrypted?(value)
          encrypted = model.type_for_attribute(field).serialize(value)
          "#{quote_column_name(field)} = #{connection.quote(encrypted)}"
        end
        connection.execute "UPDATE #{table} SET #{updates.join(', ')} WHERE id = #{Integer(row['id'])}" if updates.any?
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Do not silently decrypt personal data. Restore an approved backup with its original keys."
  end
end
