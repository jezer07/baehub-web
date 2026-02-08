require "test_helper"

class GoogleCalendarWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @couple = couples(:one)
    @user = users(:one)
  end

  test "rejects webhook when stored channel token is blank" do
    GoogleCalendarConnection.create!(
      couple: @couple,
      user: @user,
      access_token: "access-token",
      channel_id: "channel-without-token",
      channel_token: nil
    )

    post "/google_calendar/webhook", headers: {
      "X-Goog-Channel-ID" => "channel-without-token",
      "X-Goog-Resource-State" => "exists"
    }

    assert_response :unauthorized
  end

  test "accepts webhook and enqueues sync when token matches" do
    connection = GoogleCalendarConnection.create!(
      couple: @couple,
      user: @user,
      access_token: "access-token",
      channel_id: "channel-with-token",
      channel_token: "secret-token"
    )

    assert_enqueued_with(job: GoogleCalendar::PullChangesJob, args: [ connection.id ]) do
      post "/google_calendar/webhook", headers: {
        "X-Goog-Channel-ID" => "channel-with-token",
        "X-Goog-Channel-Token" => "secret-token",
        "X-Goog-Resource-State" => "exists"
      }
    end

    assert_response :ok
  end
end
