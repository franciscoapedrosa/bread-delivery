class Users::SessionsController < Devise::SessionsController
  include AuthenticationRateLimit
  prepend_before_action :enforce_authentication_rate_limit, only: :create
end
