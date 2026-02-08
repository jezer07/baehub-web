require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "create ignores external redirect targets" do
    post tasks_path, params: {
      task: { title: "Plan date night" },
      redirect_to: "https://evil.example/phish"
    }

    assert_redirected_to tasks_path
  end

  test "create allows safe in-app redirect targets" do
    post tasks_path, params: {
      task: { title: "Plan date night" },
      redirect_to: dashboard_path
    }

    assert_redirected_to dashboard_path
  end
end
