require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @couple = couples(:one)
    @expense = expenses(:one)
    sign_in @user

    @valid_params = {
      title: "Dinner",
      amount_cents: 4500,
      incurred_on: Date.today.iso8601,
      split_strategy: "equal"
    }
  end

  test "native create redirects to recede historical location" do
    post expenses_path,
      params: { expense: @valid_params },
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end

  test "web create redirects to expenses path" do
    post expenses_path, params: { expense: @valid_params }

    assert_redirected_to expenses_path
  end

  test "native update redirects to recede historical location" do
    patch expense_path(@expense),
      params: { expense: { title: "Updated Dinner" } },
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end

  test "native destroy redirects to recede historical location" do
    delete expense_path(@expense),
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end
end
