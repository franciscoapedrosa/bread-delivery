# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

seed_password = ENV.fetch("SEED_PASSWORD") do
  raise "Set SEED_PASSWORD before seeding production" if Rails.env.production?

  "password123"
end

# Admin
User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = seed_password
  u.role = "admin"
end

# Distribuidores
distributor1 = User.find_or_create_by!(email: "distrib1@example.com") do |u|
  u.password = seed_password
  u.role = "distributor"
end

distributor2 = User.find_or_create_by!(email: "distrib2@example.com") do |u|
  u.password = seed_password
  u.role = "distributor"
end

# Customers
customer1 = Customer.find_or_create_by!(name: "João", address: "Rua A, 123") do |c|
  c.bread_quantity = 5
end

customer2 = Customer.find_or_create_by!(name: "Maria", address: "Rua B, 456") do |c|
  c.bread_quantity = 3
end

# Routes
route1 = Route.find_or_create_by!(name: "Rota Algarve")
route2 = Route.find_or_create_by!(name: "Rota Viseu")

# Deliveries
Delivery.find_or_create_by!(route: route1, customer: customer1, distributor: distributor1, day_of_week: "monday") do |d|
  d.status = "pending"
end

Delivery.find_or_create_by!(route: route1, customer: customer2, distributor: distributor1, day_of_week: "monday") do |d|
  d.status = "pending"
end

Delivery.find_or_create_by!(route: route2, customer: customer1, distributor: distributor2, day_of_week: "tuesday") do |d|
  d.status = "pending"
end

Delivery.find_or_create_by!(route: route2, customer: customer2, distributor: distributor2, day_of_week: "tuesday") do |d|
  d.status = "pending"
end
