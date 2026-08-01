require "test_helper"

class RouteTest < ActiveSupport::TestCase
  test "name is unique regardless of case" do
    route = Route.new(name: routes(:one).name.downcase)
    assert_not route.valid?
  end
end
