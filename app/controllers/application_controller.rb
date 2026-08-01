class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!

  # Redireciona para login depois de logout
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  private

  def require_admin!
    return if current_user.admin?

    redirect_to authenticated_root_path, alert: "Access denied."
  end
end
