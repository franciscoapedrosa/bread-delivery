class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :prepare_weekly_agenda

  # Redireciona para login depois de logout
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  private

  def prepare_weekly_agenda
    if user_signed_in?
      DatabaseAccess.with_context(role: "system") { WeeklyRoute.materialize_through!(Date.current.end_of_week + 7) }
    end
  end

  def require_admin!
    return if current_user.admin?

    deny_access!
  end

  def deny_access!
    if request.format.json?
      render json: { error: "Acesso negado." }, status: :forbidden
    else
      redirect_to authenticated_root_path, alert: "Acesso negado."
    end
  end
end
