# Independent encryption keys: never derive these from session secrets or regenerate
# them during boot. Back up the encrypted credentials AND their master key separately.
environment_keys = %i[primary_key deterministic_key key_derivation_salt].to_h do |key|
  [ key, ENV["ACTIVE_RECORD_ENCRYPTION_#{key.to_s.upcase}"].presence ]
end.compact
if !Rails.env.test? && environment_keys.any? && environment_keys.size != 3
  raise "Configure all three ACTIVE_RECORD_ENCRYPTION keys together; partial configuration is unsafe"
end
keys = if Rails.env.test?
  { primary_key: "test-only-primary-key-not-for-production", deterministic_key: "test-only-deterministic-key", key_derivation_salt: "test-only-salt" }
elsif environment_keys.size == 3
  environment_keys
elsif Rails.root.join("config/data_encryption.yml.enc").exist?
  Rails.application.encrypted("config/data_encryption.yml.enc").config
else
  Rails.application.credentials.active_record_encryption || {}
end

%i[primary_key deterministic_key key_derivation_salt].each do |key|
  value = keys[key]
  Rails.application.config.active_record.encryption.public_send("#{key}=", value) if value
end
Rails.application.config.active_record.encryption.encrypt_fixtures = true
# Plaintext is accepted ONLY during an explicitly requested transition/backfill.
Rails.application.config.active_record.encryption.support_unencrypted_data = ENV["ENCRYPTION_MIGRATION"] == "1"
Rails.application.config.active_record.encryption.extend_queries = ENV["ENCRYPTION_MIGRATION"] == "1"
