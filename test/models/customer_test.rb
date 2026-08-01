require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "bread quantity must be positive" do
    customer = Customer.new(name: "Test", address: "Test Street", bread_quantity: 0)
    assert_not customer.valid?
  end

  test "deactivating a customer removes its deliveries" do
    customer = customers(:one)
    assert_difference("Delivery.count", -1) { customer.update!(active: false) }
  end
end
