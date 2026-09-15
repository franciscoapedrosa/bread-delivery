require "test_helper"

class VehiclesAndBakeryTest < ActionDispatch::IntegrationTest
  setup do
    @baker = User.create!(email: "baker@example.com", password: "password123", role: "baker")
    @vehicle = Vehicle.create!(name: "Carrinha branca", registration: "AA-00-BB", distributor: users(:distributor))
    @other_vehicle = Vehicle.create!(name: "Carrinha azul", registration: "CC-00-DD", distributor: users(:other_distributor))
  end

  test "admin creates vehicle with photo and distributor sees it" do
    sign_in users(:admin)
    assert_difference "Vehicle.count" do
      post vehicles_path, params: { vehicle: { name: "Carrinha nova", registration: "AB-12-CD", distributor_id: users(:distributor).id,
        photo: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png") } }
    end
    vehicle = Vehicle.find_by!(registration: "AB12CD")
    assert_equal "image/png", vehicle.photo_type
    sign_in users(:distributor)
    get photo_vehicle_path(vehicle)
    assert_response :success
    assert_equal "image/png", response.media_type
    get vehicles_path
    assert_select "h2", "Carrinha nova"
    assert_select "h2", text: "Carrinha azul", count: 0
  end

  test "distributor cannot see other vehicles or reassign one" do
    sign_in users(:distributor)
    get vehicles_path
    assert_response :success
    get vehicle_path(@other_vehicle)
    assert_response :not_found
    get photo_vehicle_path(@other_vehicle)
    assert_response :not_found
    patch vehicle_path(@vehicle), params: { vehicle: { distributor_id: users(:other_distributor).id } }
    assert_redirected_to authenticated_root_path
    assert_equal users(:distributor), @vehicle.reload.distributor
  end

  test "vehicle forms render and reassignment revokes previous access" do
    sign_in users(:admin)
    [ new_vehicle_path, edit_vehicle_path(@vehicle), vehicle_path(@vehicle) ].each do |path|
      get path
      assert_response :success
    end
    patch vehicle_path(@vehicle), params: { vehicle: { distributor_id: users(:other_distributor).id } }
    assert_redirected_to vehicle_path(@vehicle)
    sign_in users(:distributor)
    get vehicle_path(@vehicle)
    assert_response :not_found
  end

  test "baker sees only approved totals excluding cancelled deliveries" do
    routes(:one).route_stops.create!(customer: customers(:one), position: 1)
    routes(:one).route_stops.create!(customer: customers(:two), position: 2)
    run = RouteRun.create!(route: routes(:one), distributor: users(:distributor), delivery_date: Date.tomorrow)
    first, second = run.scheduled_stops.ordered.to_a
    first.request_bread(7)
    first.decide!("approved")
    second.request_bread(100)
    sign_in @baker
    get bakery_path
    assert_response :success
    assert_select ".production-highlight .bread-total", "7 pães"
    assert_select ".state-pending", text: /1 pedidos/
    second.decide!("approved")
    second.update!(status: "cancelled")
    get bakery_path
    assert_select ".production-highlight .bread-total", "7 pães"
    get bakery_path(week: Date.current + 14)
    assert_select "p", text: "Total da semana: 0 pães"
  end

  test "other roles cannot see bakery and baker cannot approve or edit" do
    sign_in users(:distributor)
    get bakery_path
    assert_redirected_to authenticated_root_path
    sign_in @baker
    get users_path
    assert_redirected_to authenticated_root_path
    post vehicles_path, params: { vehicle: { name: "Forbidden" } }
    assert_redirected_to authenticated_root_path
    get authenticated_root_path
    assert_select "h2", "Pão a preparar"
  end

  test "shared baker account is unique" do
    other = User.new(email: "otherbaker@example.com", password: "password123", role: "baker")
    assert_not other.save
    assert other.errors[:role].any?
  end

  test "registration is normalized and unique and assigned role must remain distributor" do
    duplicate = Vehicle.new(name: "Duplicado", registration: "aa 00 bb")
    assert_not duplicate.valid?
    assert_not @vehicle.update(distributor: @baker)
    assert_not users(:distributor).update(role: "admin")
  end

  test "invalid and oversized images are rejected" do
    @vehicle.photo = StringIO.new("<svg>not a photo</svg>")
    assert_not @vehicle.save
    @vehicle.photo = StringIO.new("x" * (2.megabytes + 1))
    assert_not @vehicle.save
  end

  test "distributor home combines routes and deliveries" do
    sign_in users(:distributor)
    get authenticated_root_path
    assert_select "h3", "As minhas rotas e entregas"
    assert_select "h3", "Veículos atribuídos"
    assert_select "h3", text: "As minhas entregas", count: 0
  end
end
