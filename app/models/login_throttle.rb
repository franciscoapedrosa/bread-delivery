class LoginThrottle < ApplicationRecord
  def self.allowed?(ip:, scope:, limit:, period: 15.minutes)
    now = Time.current
    window = now.to_i / period.to_i
    secret = Rails.application.key_generator.generate_key("login-rate-limit", 32)
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{scope}:#{ip}:#{window}")
    transaction do
      where(expires_at: ...now).delete_all
      insert_all([ { key: digest, expires_at: Time.at((window + 1) * period.to_i), attempts: 0 } ], unique_by: :key)
      where(key: digest).update_all("attempts = attempts + 1")
      where(key: digest).pick(:attempts) <= limit
    end
  end
end
