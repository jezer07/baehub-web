require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "web root renders landing page for unauthenticated users" do
    get root_path

    assert_response :success
    assert_match "Plan, love, and live in sync.", response.body
  end

  test "native root redirects to sign in for unauthenticated users" do
    get root_path, headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to new_user_session_path
  end
end
