require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  test "admin can view customers" do
    sign_in users(:admin)
    get customers_url
    assert_response :success
  end

  test "distributor cannot manage all customers" do
    sign_in users(:distributor)
    get customers_url
    assert_redirected_to authenticated_root_url
  end

  test "distributor can view assigned customers" do
    sign_in users(:distributor)
    get my_customers_url
    assert_response :success
    assert_select "td", text: customers(:one).name
    assert_select "td", text: customers(:two).name, count: 0
  end
end
