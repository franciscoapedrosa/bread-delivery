# RLS is defence in depth for trusted Rails queries, not an authentication protocol
# for direct database clients. Only the backend may own the runtime credentials.
module DatabaseAccess
  SETTINGS = %w[app.user_id app.role].freeze

  def self.postgresql?
    ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
  end

  def self.with_context(role:, user_id: nil)
    return yield unless postgresql?

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.transaction(requires_new: true) do
        previous = SETTINGS.map { |setting| connection.select_value("SELECT current_setting(#{connection.quote(setting)}, true)") }
        set_context(role: role, user_id: user_id)
        result = yield
        SETTINGS.zip(previous).each { |key, value| set_setting(key, value) }
        result
      end
    end
  end

  def self.set_context(role:, user_id: nil)
    return unless postgresql?

    set_setting("app.role", role)
    set_setting("app.user_id", user_id)
  end

  def self.set_setting(key, value)
    connection = ActiveRecord::Base.connection
    connection.execute("SELECT set_config(#{connection.quote(key)}, #{connection.quote(value.to_s)}, true)")
  end

  def self.verify_runtime_role!
    return unless postgresql?

    connection = ActiveRecord::Base.connection
    unsafe = connection.select_value(<<~SQL)
      SELECT r.rolsuper OR r.rolbypassrls
        OR has_schema_privilege(current_user, 'public', 'CREATE')
        OR has_schema_privilege(current_user, 'app_private', 'CREATE')
        OR EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname IN ('users','customers','deliveries','routes','route_stops','route_runs','scheduled_stops','weekly_routes','vehicles','login_throttles')
          AND pg_has_role(current_user, c.relowner, 'MEMBER')
      ) FROM pg_roles r WHERE r.rolname = current_user
    SQL
    raise "Unsafe database role: runtime must not own tables, create schema objects, be superuser, or BYPASSRLS" if unsafe
    protected_tables = connection.select_value("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname IN ('users','customers','deliveries','routes','route_stops','route_runs','scheduled_stops','weekly_routes','vehicles','login_throttles') AND c.relrowsecurity")
    raise "RLS policies are missing; run migrations with the separate owner connection" unless protected_tables.to_i == 10
  end
end
