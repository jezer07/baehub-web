class GoogleCalendarWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    channel_id = request.headers["X-Goog-Channel-ID"]
    resource_state = request.headers["X-Goog-Resource-State"]

    connection = GoogleCalendarConnection.find_by(channel_id: channel_id)
    if connection && %w[exists sync].include?(resource_state)
      GoogleCalendar::PullChangesJob.perform_later(connection.id)
    end

    head :ok
  end
end
