# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_15_120000) do
  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.integer "bread_quantity"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["name", "address", "bread_quantity"], name: "index_customers_on_name_and_address_and_bread_quantity", unique: true
    t.index ["user_id"], name: "index_customers_on_user_id", unique: true
  end

  create_table "deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.string "day_of_week", null: false
    t.integer "distributor_id", null: false
    t.integer "route_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_deliveries_on_customer_id"
    t.index ["distributor_id"], name: "index_deliveries_on_distributor_id"
    t.index ["route_id", "customer_id", "distributor_id", "day_of_week"], name: "idx_unique_delivery_quad", unique: true
    t.index ["route_id"], name: "index_deliveries_on_route_id"
  end

  create_table "route_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "delivery_date", null: false
    t.integer "distributor_id", null: false
    t.integer "position", default: 1, null: false
    t.integer "route_id", null: false
    t.datetime "updated_at", null: false
    t.index ["distributor_id"], name: "index_route_runs_on_distributor_id"
    t.index ["route_id", "delivery_date"], name: "index_route_runs_on_route_id_and_delivery_date", unique: true
    t.index ["route_id"], name: "index_route_runs_on_route_id"
  end

  create_table "route_stops", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.integer "position", default: 1, null: false
    t.integer "route_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_route_stops_on_customer_id"
    t.index ["route_id", "customer_id"], name: "index_route_stops_on_route_id_and_customer_id", unique: true
    t.index ["route_id"], name: "index_route_stops_on_route_id"
  end

  create_table "routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index "lower(name)", name: "index_routes_on_lower_name", unique: true
  end

  create_table "scheduled_stops", force: :cascade do |t|
    t.string "address", null: false
    t.string "approval_status", default: "awaiting_request", null: false
    t.integer "approved_quantity"
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.integer "position", null: false
    t.integer "requested_quantity"
    t.integer "route_run_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_scheduled_stops_on_customer_id"
    t.index ["route_run_id", "customer_id"], name: "index_scheduled_stops_on_route_run_id_and_customer_id", unique: true
    t.index ["route_run_id"], name: "index_scheduled_stops_on_route_run_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "distributor", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "customers", "users"
  add_foreign_key "deliveries", "customers"
  add_foreign_key "deliveries", "routes"
  add_foreign_key "deliveries", "users", column: "distributor_id"
  add_foreign_key "route_runs", "routes"
  add_foreign_key "route_runs", "users", column: "distributor_id"
  add_foreign_key "route_stops", "customers"
  add_foreign_key "route_stops", "routes"
  add_foreign_key "scheduled_stops", "customers"
  add_foreign_key "scheduled_stops", "route_runs"
end
