#!/usr/bin/env bash
set -o errexit

bundle install
bin/rails assets:precompile
# Only an isolated migration job may receive the owner credential. The normal
# web build skips DB writes; its runtime role is checked by the middleware.
if [ "${RUN_DATABASE_MIGRATIONS:-0}" = "1" ]; then
  : "${MIGRATION_DATABASE_URL:?Configure the separate Neon owner connection}"
  : "${DATABASE_APP_ROLE:?Configure the restricted Neon runtime role name}"
  DATABASE_URL="$MIGRATION_DATABASE_URL" bin/rails db:migrate
  if [ "${RUN_SEEDS:-0}" = "1" ]; then
    DATABASE_URL="$MIGRATION_DATABASE_URL" bin/rails db:seed
  fi
else
  echo "Database writes skipped. Run migrations in the separate owner job before starting this release."
fi
