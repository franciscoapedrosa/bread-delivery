module AuthenticationRateLimit
  extend ActiveSupport::Concern

  private

  def enforce_authentication_rate_limit
    limit = controller_name == "sessions" ? 20 : 5
    return if LoginThrottle.allowed?(ip: request.remote_ip, scope: controller_name, limit: limit)

    response.set_header("Retry-After", "900")
    message = "Demasiadas tentativas. Aguarde 15 minutos e tente novamente."
    if request.format.json?
      render json: { error: message }, status: :too_many_requests
    else
      render plain: message, status: :too_many_requests
    end
  end
end
