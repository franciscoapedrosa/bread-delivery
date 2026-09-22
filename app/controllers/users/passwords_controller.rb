class Users::PasswordsController < Devise::PasswordsController
  include AuthenticationRateLimit
  prepend_before_action :enforce_authentication_rate_limit, only: %i[create update]
end
