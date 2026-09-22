# Security review and deployment

## Implemented and verified locally

- Every business controller inherits `authenticate_user!`; unauthenticated JSON requests return 401. Administrative operations check roles server-side (403 for JSON). Login, password recovery, static assets and the minimal `/up` health check are intentionally public. There is no separate token-based/public API in this application. Session authentication and CSRF protection remain enabled; do not disable CSRF to add an API.
- Devise stores **salted bcrypt hashes**, not decryptable passwords (cost 12 outside tests). Existing passwords do not need conversion.
- Five invalid passwords lock an account for 15 minutes. A persistent database-backed limit also permits at most 20 login attempts/IP/15-minute fixed window, including nonexistent accounts. Recovery/reset is limited to five attempts/IP/window. HTTP 429 includes Retry-After. Counts survive process restarts and are shared between Render instances using the same DB. Only HMAC bucket identifiers, counters and expiration times are stored; old buckets are removed. Devise uses generic responses to reduce account enumeration. A distributed attack still requires perimeter protection/monitoring; lockouts can themselves be abused for temporary denial of service.
- Active Record Encryption protects `users.email`, `customers.name`, `customers.address`, `scheduled_stops.address` and `scheduled_stops.rejection_reason`. Email/name/customer-address use deterministic encryption for existing equality lookups and unique indexes; identical plaintext can therefore be correlated. Other encrypted fields use randomized encryption. Sorting and bakery totals no longer depend on SQL sorting/grouping plaintext names.
- Logs filter email, name, address, password, tokens and rejection reason. This does not remove historical logs or backups.
- Calendar generation is bounded to one year ahead so a crafted far-future date cannot generate thousands of years of route instances during a request.
- PostgreSQL migrations define RLS on all ten application tables, with column-change guards for users and deliveries. SQLite cannot execute these policies: controller authorization still applies locally.

## Important RLS trust boundary

The browser never connects directly to Neon and never chooses the database actor. Rails establishes transaction-local `app.user_id` and `app.role` after Devise authenticates the session. The context is reset after the request (including rollback) before reusing connections. Recurrence generation uses a narrowly scoped internal `system` context.

The policies protect against accidental unscoped queries and cross-account record access. **They do not authenticate untrusted SQL clients**: a holder of the backend database credential can set these session variables. Never expose DATABASE_URL to browsers, customers, public SQL consoles or a Data API. SQL injection and compromised backend credentials require independent protection; RLS is not a substitute.

The internal `auth` context can read/update users for Devise authentication, lock counters, remember-me and recovery. It cannot read business records. A trigger prevents changing role/email/ownership during that phase. Admin/system can manage data; customers can read their own profile/deliveries and submit quantities within the cutoff; distributors can read assigned data and update delivery status; bakers can read production data but cannot approve/write it.

Small `SECURITY DEFINER` boolean functions avoid recursive policy joins. They have a fixed search_path, no dynamic SQL, no returned personal data, and no PUBLIC execution rights. Their owner is the migration role. Tables use ENABLE RLS, **not FORCE**, because these trusted lookup functions require owner bypass. The web process must use a different non-owner, non-superuser, NOBYPASSRLS role with no membership in the owner role. The production middleware rejects unsafe roles and missing RLS tables. Owner connections intentionally bypass policies and must never be used by the web process.

## Render + Neon activation (not yet performed)

See [the deployment preparation checklist](DEPLOY_CHECKLIST.md) for the current stop points. The local Blueprint declares a Free web service: Render Free does not support one-off jobs. Confirm the live plan and choose an authorized isolated migration executor (for example, a supervised local process) before activation; do not solve this by giving owner credentials to the web service. Disable automatic deployment in the actual Render service, with approval, before pushing this release.

1. Create an isolated Neon branch and a recoverable backup before touching production. Stop writes while encrypting existing data. This release must not share a database with old application instances that still expect plaintext.
2. In the Neon SQL editor, using the owner, create a dedicated login role. Set its password privately using Neon/your secret manager, never in Git or chat:

   ```sql
   CREATE ROLE bread_app LOGIN NOSUPERUSER NOBYPASSRLS NOINHERIT;
   ```

   Do not grant the owner role to it. Do not make it table/schema owner. Use the role creation mechanism supported by Neon if SQL role administration is restricted. The migration grants only schema USAGE, table SELECT/INSERT/UPDATE/DELETE and sequence USAGE/SELECT; it does not grant DDL, TRUNCATE or ownership.
3. Supply three **independent random** keys in Render's secret environment:
   - ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
   - ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
   - ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT

   Alternatively use `config/data_encryption.yml.enc` with its matching RAILS_MASTER_KEY. `ruby bin/setup-encryption` generates this encrypted artifact only if it does not exist and never prints the keys. The local file has already been generated. Back up the encrypted file and master key separately. Environment keys take precedence when all three are present. Never use test keys in production and never regenerate keys on restart. Losing/rotating keys without a migration makes existing data unreadable. Session secrets and data-encryption keys are separate.
4. Configure Render:
   - DATABASE_URL = Neon connection for **bread_app** (runtime, TLS required).
   - MIGRATION_DATABASE_URL = separate Neon **owner** connection, provided **only to the isolated migration job**, not the web service (prefer direct/unpooled for migrations, TLS required).
   - DATABASE_APP_ROLE = bread_app.
   - Existing RAILS_MASTER_KEY / SECRET_KEY_BASE and APP_HOST remain required as applicable.

   `bin/render-build.sh` skips database writes by default. An isolated migration job must set RUN_DATABASE_MIGRATIONS=1 and receives MIGRATION_DATABASE_URL; it must finish before starting this release. Do not put the owner credential in the web service's shared build/runtime environment. Missing RLS will cause runtime checks to reject requests, rather than silently run unprotected. RUN_SEEDS=1 is a separate explicit opt-in requiring a private SEED_PASSWORD; demo accounts are no longer created on every deployment. If the Render service uses a different build/pre-deploy command, update it accordingly.
5. Run migrations with the owner on the test branch. The encryption migration widens columns, verifies keys, encrypts existing values transactionally, and refuses an automatic rollback to plaintext. It must finish before the new web instance starts. Reads are strict by default. ENCRYPTION_MIGRATION=1 is an explicit temporary escape hatch for a supervised transition, never a permanent production setting.
6. Run the tests with an actual restricted role, then deploy the new web code and restart instances. Verify login, reset, admin approval, customer request and distributor delivery. Confirm a customer cannot query another customer's row and that no-context SQL returns zero business rows.
7. After verification, handle retention of pre-encryption backups, Neon history/branches, logs and dead database pages. Encryption does not retroactively protect these copies. Do not delete the only recoverable backup or the keys. Plan key rotation with Rails previous-key support, not by replacing environment values blindly.

No Neon configuration/database or production data was changed during the local implementation. During deployment preparation on 22/09/2026, with explicit user approval, Render Auto-Deploy was changed to Off and the local Blueprint aligned with that setting. A manual Neon snapshot of production was subsequently created at 10:52:09 UTC, with no expiry shown. With further approval, Neon successfully restored it to the separate branch `security-test-2026-09-22` (`br-purple-night-zap4uosc`), without migrating production connections. Data integrity and application behaviour on that copy are not yet validated. No release was deployed and no production records were rewritten; encryption keys, restricted runtime credentials and migrations still need activation as described above.

## Tests and schema handling

```sh
bin/rails test
bin/brakeman --no-pager
```

PostgreSQL uses a separate TEST_DATABASE_URL (never production). The isolated Docker test database uses port 55432 on loopback only; credentials are disposable test values. Run PostgreSQL tests serially, after creating `bread_app` and installing migrations:

```sh
RAILS_ENV=test TEST_DATABASE_URL=... bin/rails db:migrate
RAILS_ENV=test TEST_DATABASE_URL=... bin/rails security:install_rls
RAILS_ENV=test TEST_DATABASE_URL=... bin/rails test test/models/row_security_test.rb test/controllers/postgresql_authentication_test.rb
```

The test setup loads fixtures through the owner, then executes isolation checks with `SET LOCAL ROLE bread_app`; using only owner connections would hide RLS failures. Test keys and fixtures are separate from local/production data. PostgreSQL tests do not overwrite the portable SQLite schema dump.

Ruby `schema.rb` does not capture RLS/functions/triggers. The `db:migrate`, `db:schema:load` and `db:test:prepare` task hooks reinstall the policy migration on a fresh PostgreSQL schema. Raw SQL/schema restores outside these tasks must run `security:install_rls` explicitly. The installer is transactional and rejects a partial/unexpected policy count; it does not silently replace existing policies. Production startup also checks the runtime role and that all ten tables have RLS enabled.

CI also restores the PostgreSQL schema with the helper functions still present and reruns the restricted-role tests, guarding against policies being lost during restore. Partial encryption-key environment configuration is rejected rather than silently falling back to another key set.

## Local data backup

Before converting the local database, `ruby bin/backup-local-security` created an encrypted SQLite snapshot in `storage/before-security-*.sqlite3.enc`. It uses the existing Rails master key and is not tracked by Git. To recover, first stop the application, decrypt to a **new** SQLite file using `Rails.application.encrypted(path).read`, verify it, and explicitly choose which database/code version to restore. Do not overwrite the current database without approval.

## Primary references

- [Rails Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html)
- [PostgreSQL row security policies and owner bypass](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- Devise 5.0.4 installed source (`database_authenticatable`, `lockable`, `recoverable`) was inspected for authentication/lockout behaviour.
