require Rails.root.join("lib/database_security_context")
Rails.application.config.middleware.insert_before Warden::Manager, DatabaseSecurityContext

Warden::Manager.after_set_user do |user, _warden, _options|
  DatabaseAccess.set_context(role: user.role, user_id: user.id)
end
Warden::Manager.before_logout do |_user, _warden, _options|
  DatabaseAccess.set_context(role: "auth")
end
