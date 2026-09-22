class AddPostgresqlRowSecurity < ActiveRecord::Migration[8.1]
  TABLES = %w[users customers deliveries routes route_stops route_runs scheduled_stops weekly_routes vehicles login_throttles].freeze

  def up
    return unless connection.adapter_name == "PostgreSQL"

    role_name = ENV.fetch("DATABASE_APP_ROLE", "bread_app")
    raise "Create the restricted DATABASE_APP_ROLE before migrating" unless select_value("SELECT 1 FROM pg_roles WHERE rolname = #{connection.quote(role_name)}")
    app_role = connection.quote_column_name(role_name)
    execute "CREATE SCHEMA IF NOT EXISTS app_private"
    execute "REVOKE CREATE ON SCHEMA public FROM PUBLIC"
    execute "REVOKE ALL ON SCHEMA app_private FROM PUBLIC"
    execute "GRANT USAGE ON SCHEMA public, app_private TO #{app_role}"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION app_private.actor_id() RETURNS bigint LANGUAGE sql STABLE
      AS $$ SELECT NULLIF(current_setting('app.user_id', true), '')::bigint $$;
      CREATE OR REPLACE FUNCTION app_private.actor_role() RETURNS text LANGUAGE sql STABLE
      AS $$ SELECT COALESCE(current_setting('app.role', true), '') $$;

      -- These small boolean lookups intentionally execute as the separate table
      -- owner, avoiding recursive RLS joins. They never return personal data.
      CREATE OR REPLACE FUNCTION app_private.can_read_customer(target bigint) RETURNS boolean
      LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public SET row_security = off
      AS $$ SELECT
        (app_private.actor_role() = 'customer' AND EXISTS (SELECT 1 FROM public.customers c WHERE c.id = target AND c.user_id = app_private.actor_id())) OR
        (app_private.actor_role() = 'distributor' AND (
          EXISTS (SELECT 1 FROM public.scheduled_stops s JOIN public.route_runs r ON r.id = s.route_run_id WHERE s.customer_id = target AND r.distributor_id = app_private.actor_id()) OR
          EXISTS (SELECT 1 FROM public.deliveries d WHERE d.customer_id = target AND d.distributor_id = app_private.actor_id()))) OR
        (app_private.actor_role() = 'baker' AND EXISTS (SELECT 1 FROM public.scheduled_stops s WHERE s.customer_id = target))
      $$;

      CREATE OR REPLACE FUNCTION app_private.can_read_run(target bigint) RETURNS boolean
      LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public SET row_security = off
      AS $$ SELECT
        app_private.actor_role() = 'baker' OR
        (app_private.actor_role() = 'distributor' AND EXISTS (SELECT 1 FROM public.route_runs r WHERE r.id = target AND r.distributor_id = app_private.actor_id())) OR
        (app_private.actor_role() = 'customer' AND EXISTS (SELECT 1 FROM public.scheduled_stops s JOIN public.customers c ON c.id = s.customer_id WHERE s.route_run_id = target AND c.user_id = app_private.actor_id()))
      $$;

      CREATE OR REPLACE FUNCTION app_private.can_read_route(target bigint) RETURNS boolean
      LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public SET row_security = off
      AS $$ SELECT app_private.actor_role() = 'distributor' AND (
        EXISTS (SELECT 1 FROM public.route_runs r WHERE r.route_id = target AND r.distributor_id = app_private.actor_id()) OR
        EXISTS (SELECT 1 FROM public.deliveries d WHERE d.route_id = target AND d.distributor_id = app_private.actor_id()))
      $$;

      CREATE OR REPLACE FUNCTION app_private.owns_stop(target bigint) RETURNS boolean
      LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public SET row_security = off
      AS $$ SELECT EXISTS (SELECT 1 FROM public.scheduled_stops s JOIN public.customers c ON c.id = s.customer_id WHERE s.id = target AND c.user_id = app_private.actor_id()) $$;
    SQL
    execute "REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app_private FROM PUBLIC"
    execute "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_private TO #{app_role}"

    TABLES.each do |table|
      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY"
      execute "REVOKE ALL ON #{table} FROM PUBLIC"
      execute "GRANT SELECT, INSERT, UPDATE, DELETE ON #{table} TO #{app_role}"
      execute "GRANT USAGE, SELECT ON SEQUENCE #{table}_id_seq TO #{app_role}"
      policy(table, "administration", "ALL", "app_private.actor_role() IN ('admin', 'system')", app_role)
    end

    # Authentication is an internal Rails phase, never a role accepted from HTTP.
    policy("users", "authentication_read", "SELECT", "app_private.actor_role() = 'auth' OR id = app_private.actor_id()", app_role)
    policy("users", "authentication_update", "UPDATE", "app_private.actor_role() = 'auth' OR id = app_private.actor_id()", app_role)
    policy("login_throttles", "authentication", "ALL", "app_private.actor_role() = 'auth' OR app_private.actor_id() IS NOT NULL", app_role)
    policy("customers", "visible_customers", "SELECT", "app_private.can_read_customer(id)", app_role)
    policy("routes", "visible_routes", "SELECT", "app_private.can_read_route(id)", app_role)
    policy("route_stops", "visible_route_stops", "SELECT", "app_private.can_read_route(route_id)", app_role)
    policy("route_runs", "visible_runs", "SELECT", "app_private.can_read_run(id)", app_role)
    policy("vehicles", "assigned_vehicles", "SELECT", "app_private.actor_role() = 'distributor' AND distributor_id = app_private.actor_id()", app_role)
    %w[SELECT UPDATE].each do |command|
      policy("deliveries", "assigned_#{command.downcase}", command, "app_private.actor_role() = 'distributor' AND distributor_id = app_private.actor_id()", app_role)
      expression = "(app_private.actor_role() = 'customer' AND app_private.owns_stop(id)) OR (app_private.actor_role() = 'distributor' AND app_private.can_read_run(route_run_id))"
      expression += " OR app_private.actor_role() = 'baker'" if command == "SELECT"
      policy("scheduled_stops", "assigned_#{command.downcase}", command, expression, app_role)
    end

    # RLS limits rows, not columns. Prevent privilege/ownership/status escalation
    # even when a query accidentally writes fields outside strong parameters.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION app_private.guard_update() RETURNS trigger
      LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
      DECLARE allowed text[]; run_date date; deadline timestamptz;
      BEGIN
        IF app_private.actor_role() IN ('admin', 'system') THEN RETURN NEW; END IF;
        IF TG_TABLE_NAME = 'users' THEN
          allowed := ARRAY['encrypted_password','reset_password_token','reset_password_sent_at','remember_created_at','failed_attempts','locked_at','updated_at'];
        ELSIF TG_TABLE_NAME = 'scheduled_stops' AND app_private.actor_role() = 'customer' THEN
          allowed := ARRAY['requested_quantity','approved_quantity','approval_status','rejection_reason','updated_at'];
          SELECT r.delivery_date INTO run_date FROM public.route_runs r WHERE r.id = OLD.route_run_id AND NOT r.removed;
          deadline := ((run_date - 1) + time '23:00') AT TIME ZONE 'Europe/Lisbon';
          IF run_date IS DISTINCT FROM ((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Lisbon')::date + 1)
            OR CURRENT_TIMESTAMP >= deadline OR OLD.status <> 'pending'
            OR NEW.approval_status <> 'pending' OR NEW.approved_quantity IS NOT NULL
            OR NEW.rejection_reason IS NOT NULL OR NEW.requested_quantity IS NULL
            OR NEW.requested_quantity < 0 OR NEW.requested_quantity > 100000
            OR NOT EXISTS (SELECT 1 FROM public.customers c WHERE c.id = OLD.customer_id AND c.active)
          THEN RAISE EXCEPTION 'Forbidden order change' USING ERRCODE = '42501'; END IF;
        ELSIF TG_TABLE_NAME IN ('scheduled_stops','deliveries') AND app_private.actor_role() = 'distributor' THEN
          allowed := ARRAY['status','updated_at'];
          IF NEW.status NOT IN ('pending','delivered','cancelled') THEN RAISE EXCEPTION 'Invalid delivery status' USING ERRCODE = '42501'; END IF;
          IF TG_TABLE_NAME = 'scheduled_stops' AND NEW.status = 'delivered' THEN
            IF OLD.approval_status <> 'approved' OR COALESCE(OLD.approved_quantity, 0) <= 0 THEN
              RAISE EXCEPTION 'Bread must be approved first' USING ERRCODE = '42501';
            END IF;
          END IF;
        ELSE
          RAISE EXCEPTION 'Forbidden update' USING ERRCODE = '42501';
        END IF;
        IF (to_jsonb(NEW) - allowed) IS DISTINCT FROM (to_jsonb(OLD) - allowed) THEN
          RAISE EXCEPTION 'Forbidden column change' USING ERRCODE = '42501';
        END IF;
        RETURN NEW;
      END $$;
      REVOKE ALL ON FUNCTION app_private.guard_update() FROM PUBLIC;
    SQL
    %w[users scheduled_stops deliveries].each do |table|
      execute "CREATE TRIGGER guard_update BEFORE UPDATE ON #{table} FOR EACH ROW EXECUTE FUNCTION app_private.guard_update()"
    end
  end

  def down
    return unless connection.adapter_name == "PostgreSQL"

    raise ActiveRecord::IrreversibleMigration, "Removing access policies requires an explicit, reviewed security migration."
  end

  private

  def policy(table, name, command, expression, role)
    clause = "USING (#{expression})"
    clause += " WITH CHECK (#{expression})" if %w[ALL UPDATE].include?(command)
    execute "CREATE POLICY #{name} ON #{table} FOR #{command} TO #{role} #{clause}"
  end
end
