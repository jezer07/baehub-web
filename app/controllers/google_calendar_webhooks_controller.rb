class GoogleCalendarWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    channel_id = request.headers["X-Goog-Channel-ID"]
    channel_token = request.headers["X-Goog-Channel-Token"]
    resource_state = request.headers["X-Goog-Resource-State"]

    connection = GoogleCalendarConnection.find_by(channel_id: channel_id)

    unless connection && valid_channel_token?(connection, channel_token)
      head :unauthorized
      return
    end

    if %w[exists sync].include?(resource_state)
      GoogleCalendar::PullChangesJob.perform_later(connection.id)
    end

    head :ok
  end

  private

  def valid_channel_token?(connection, token)
    return false if connection.channel_token.blank? || token.blank?

    ActiveSupport::SecurityUtils.secure_compare(connection.channel_token, token)
  end
end
