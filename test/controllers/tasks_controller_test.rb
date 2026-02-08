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

  test "native create redirects to recede historical location" do
    post tasks_path,
      params: { task: { title: "Native task" } },
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end

  test "native update redirects to recede historical location" do
    task = @user.couple.tasks.create!(title: "Update me", creator: @user)

    patch task_path(task),
      params: { task: { title: "Updated title" } },
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end

  test "native destroy redirects to recede historical location" do
    task = @user.couple.tasks.create!(title: "Delete me", creator: @user)

    delete task_path(task),
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end
end
