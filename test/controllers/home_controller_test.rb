require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in users(:admin)
    get home_index_url
    assert_response :success
  end

  test "redirects guests to sign in" do
    get home_index_url
    assert_redirected_to new_user_session_url
  end
end
