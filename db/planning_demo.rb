# Optional local demonstration: bin/rails runner db/planning_demo.rb
abort "A demonstração só pode ser criada em desenvolvimento." unless Rails.env.development?

User.transaction do
  unless User.exists?(role: "baker")
    User.create!(email: "padeiro.demo@example.com", password: "pao-local-2026", role: "baker")
  end
  distributor = User.find_or_initialize_by(email: "distribuidor.demo@example.com")
  if distributor.new_record?
    distributor.assign_attributes(role: "distributor", password: "pao-local-2026")
    distributor.save!
  end
  Vehicle.find_or_create_by!(registration: "DEMO01") do |vehicle|
    vehicle.name = "Carrinha de demonstração"
    vehicle.distributor = distributor
  end
  route = Route.find_or_create_by!(name: "Demonstração · Centro")
  [ [ "cliente.demo@example.com", "Maria (demonstração)", "Praça do Comércio, Lisboa" ],
    [ "cliente2.demo@example.com", "Café da Praça (demonstração)", "Praça Dom Pedro IV, Lisboa" ] ].each_with_index do |(email, name, address), index|
    user = User.find_or_initialize_by(email: email)
    if user.new_record?
      user.assign_attributes(role: "customer", password: "pao-local-2026")
      user.build_customer(name: name, address: address, bread_quantity: 1)
      user.save!
    end
    route.route_stops.find_or_create_by!(customer: user.customer) { |stop| stop.position = index + 1 }
  end
  unless route.route_runs.exists?(delivery_date: Date.tomorrow)
    run = route.route_runs.create!(distributor: distributor, delivery_date: Date.tomorrow, position: 1)
    run.scheduled_stops.ordered.each_with_index do |stop, index|
      stop.request_bread((index + 1) * 5)
    end
    run.scheduled_stops.ordered.first.decide!("approved")
  end
end
puts "Demonstração local criada."
