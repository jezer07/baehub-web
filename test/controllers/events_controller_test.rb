require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @couple = couples(:one)
    sign_in @user

    @valid_params = {
      title: "Date Night",
      starts_at: 1.day.from_now.iso8601,
      ends_at: 1.day.from_now.advance(hours: 2).iso8601
    }
  end

  test "native create redirects to recede historical location" do
    post events_path,
      params: { event: @valid_params },
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end

  test "web create redirects to events path" do
    post events_path, params: { event: @valid_params }

    assert_redirected_to events_path
  end

  test "native update redirects to recede historical location" do
    event = @couple.events.create!(
      title: "Existing Event",
      starts_at: 2.days.from_now,
      ends_at: 2.days.from_now.advance(hours: 1),
      creator: @user
    )

    patch event_path(event),
      params: { event: { title: "Updated Event" } },
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end

  test "native destroy redirects to recede historical location" do
    event = @couple.events.create!(
      title: "Event to Delete",
      starts_at: 3.days.from_now,
      ends_at: 3.days.from_now.advance(hours: 1),
      creator: @user
    )

    delete event_path(event),
      headers: { "HTTP_USER_AGENT" => "Hotwire Native iOS" }

    assert_redirected_to turbo_recede_historical_location_url
  end
end
