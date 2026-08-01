require "test_helper"

class DeliveriesControllerTest < ActionDispatch::IntegrationTest
  test "distributor sees only assigned deliveries" do
    sign_in users(:distributor)
    get deliveries_url
    assert_response :success
    assert_select "td", text: customers(:one).name
    assert_select "td", text: customers(:two).name, count: 0
  end

  test "distributor cannot view another distributor delivery" do
    sign_in users(:distributor)
    get delivery_url(deliveries(:two))
    assert_redirected_to deliveries_url
  end

  test "distributor reset only changes own deliveries" do
    deliveries(:one).update!(status: "delivered")
    sign_in users(:distributor)
    post reset_week_deliveries_url
    assert_equal "pending", deliveries(:one).reload.status
    assert_equal "delivered", deliveries(:two).reload.status
  end

  test "only admin can delete the week" do
    sign_in users(:distributor)
    assert_no_difference("Delivery.count") { delete destroy_week_deliveries_url }
    assert_redirected_to authenticated_root_url
  end
end
