namespace :security do
  desc "Install PostgreSQL policies after a Ruby schema load (requires the separate owner connection)"
  task install_rls: :environment do
    next unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
    require Rails.root.join("db/migrate/20260920010200_add_postgresql_row_security")
    count = ActiveRecord::Base.connection.select_value("SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('users','customers','deliveries','routes','route_stops','route_runs','scheduled_stops','weekly_routes','vehicles','login_throttles')").to_i
    if count.zero?
      ActiveRecord::Base.transaction { AddPostgresqlRowSecurity.new.up }
    elsif count != 22
      raise "Unexpected RLS policy set (#{count}); review before using this database"
    end
  end
end

# Ruby schema dumps cannot represent policies/functions/triggers. These hooks
# restore them on fresh databases instead of silently creating an unprotected DB.
%w[db:migrate db:schema:load db:test:prepare].each do |task_name|
  Rake::Task[task_name].enhance do
    Rake::Task["security:install_rls"].reenable
    Rake::Task["security:install_rls"].invoke
  end
end
