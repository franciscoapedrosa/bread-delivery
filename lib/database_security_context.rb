require_relative "database_access"

class DatabaseSecurityContext
  def initialize(app)
    @app = app
  end

  def call(env)
    # Runs before Warden and routing, including session/remember-me restoration.
    DatabaseAccess.verify_runtime_role! if Rails.env.production?
    DatabaseAccess.with_context(role: "auth") { @app.call(env) }
  end
end
