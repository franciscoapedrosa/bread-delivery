require "test_helper"

class DeliveryTest < ActiveSupport::TestCase
  test "normalizes the day before validation" do
    delivery = deliveries(:one)
    delivery.day_of_week = " MONDAY "
    assert delivery.valid?
    assert_equal "monday", delivery.day_of_week
  end

  test "rejects an unsupported status" do
    delivery = deliveries(:one)
    delivery.status = "unknown"
    assert_not delivery.valid?
  end
end
