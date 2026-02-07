require "securerandom"
require "time"

module GoogleCalendar
  class SyncService
    def self.default_time_min
      1.year.ago
    end

    def initialize(connection)
      @connection = connection
      @client = Client.new(connection)
    end

    def available_calendars
      response = @client.list_calendars
      Array(response["items"]).filter { |item| %w[owner writer].include?(item["accessRole"]) }.map do |item|
        {
          id: item["id"],
          summary: item["summary"],
          access_role: item["accessRole"],
          primary: item["primary"]
        }
      end
    end

    def initial_sync!
      pull_changes(full_sync: true)
      ensure_watch!
    end

    def pull_changes(full_sync: false)
      calendar_id = @connection.calendar_id
      return if calendar_id.blank?

      items = []
      params = {
        showDeleted: true,
        singleEvents: false,
        maxResults: 2500
      }

      if !full_sync && @connection.sync_token.present?
        params[:syncToken] = @connection.sync_token
      else
        params[:timeMin] = self.class.default_time_min.utc.iso8601
      end

      loop do
        response = @client.list_events(calendar_id, params)
        items.concat(Array(response["items"]))
        page_token = response["nextPageToken"]
        if page_token.present?
          params[:pageToken] = page_token
        else
          next_sync_token = response["nextSyncToken"]
          attributes = { last_synced_at: Time.current }
          attributes[:sync_token] = next_sync_token if next_sync_token.present?
          @connection.update!(attributes)
          break
        end
      end

      apply_remote_items(items)
    rescue RequestError => e
      if e.sync_token_invalid?
        @connection.update!(sync_token: nil)
        pull_changes(full_sync: true)
      else
        raise
      end
    end

    def upsert_event(event)
      calendar_id = @connection.calendar_id
      return if calendar_id.blank?

      if event.google_event_updated_at.present? && event.updated_at <= event.google_event_updated_at
        return
      end

      payload = EventMapper.to_google_event(event, timezone: event.couple.timezone)

      response = if event.google_event_id.present?
        @client.update_event(calendar_id, event.google_event_id, payload)
      else
        @client.insert_event(calendar_id, payload)
      end

      update_event_from_remote(event, response)
    end

    def delete_event(google_event_id)
      calendar_id = @connection.calendar_id
      return if calendar_id.blank?

      @client.delete_event(calendar_id, google_event_id)
    rescue RequestError => e
      raise unless e.status == 404
    end

    def ensure_watch!
      calendar_id = @connection.calendar_id
      return if calendar_id.blank?

      if @connection.channel_id.present? &&
          @connection.channel_resource_id.present? &&
          @connection.channel_token.present? &&
          @connection.channel_expires_at.present? &&
          @connection.channel_expires_at > 1.day.from_now
        return
      end

      stop_watch! if @connection.channel_id.present? && @connection.channel_resource_id.present?

      channel_id = SecureRandom.uuid
      channel_token = SecureRandom.hex(32)
      response = @client.watch_events(calendar_id, webhook_url, channel_id, channel_token: channel_token)
      @connection.update!(
        channel_id: channel_id,
        channel_token: channel_token,
        channel_resource_id: response["resourceId"],
        channel_expires_at: parse_channel_expiration(response["expiration"])
      )
    end

    def stop_watch!
      return if @connection.channel_id.blank? || @connection.channel_resource_id.blank?

      @client.stop_channel(@connection.channel_id, @connection.channel_resource_id)
    rescue RequestError
    ensure
      @connection.update!(
        channel_id: nil,
        channel_token: nil,
        channel_resource_id: nil,
        channel_expires_at: nil
      )
    end

    private

    def apply_remote_items(items)
      timezone = @connection.couple.timezone

      items.each do |item|
        next if item["recurringEventId"].present? && item["recurrence"].blank?

        google_event_id = item["id"]
        event = @connection.couple.events.find_by(google_event_id: google_event_id)

        if item["status"] == "cancelled"
          if event
            event.skip_google_sync = true
            event.destroy
          end
          next
        end

        remote_updated_at = Time.iso8601(item["updated"]) rescue nil

        if event
          next if remote_updated_at.present? && event.updated_at > remote_updated_at

          attrs = EventMapper.from_google_event(item, timezone: timezone)
          event.skip_google_sync = true
          event.update!(attrs.merge(sync_to_google: true))
          update_event_from_remote(event, item, updated_at: remote_updated_at)
        else
          attrs = EventMapper.from_google_event(item, timezone: timezone)
          new_event = @connection.couple.events.new(attrs.merge(sync_to_google: true))
          new_event.creator = @connection.user
          new_event.skip_google_sync = true
          new_event.save!
          update_event_from_remote(new_event, item, updated_at: remote_updated_at)
        end
      end
    end

    def update_event_from_remote(event, item, updated_at: nil)
      remote_updated_at = updated_at || (Time.iso8601(item["updated"]) rescue nil) || Time.current
      event.update_columns(
        google_event_id: item["id"],
        google_event_etag: item["etag"],
        google_event_updated_at: remote_updated_at,
        google_last_synced_at: Time.current,
        google_sync_status: "synced",
        google_sync_error: nil,
        updated_at: remote_updated_at
      )
    end

    def webhook_url
      host = ENV["APP_HOST"].presence || ENV["MAILER_HOST"].presence
      if host.blank?
        if Rails.env.production?
          raise "APP_HOST environment variable is required for Google Calendar webhooks"
        end
        host = "localhost:3000"
      end

      return "#{host}/google_calendar/webhook" if host.start_with?("http")

      protocol = ENV.fetch("APP_PROTOCOL", host.start_with?("localhost") ? "http" : "https")
      "#{protocol}://#{host}/google_calendar/webhook"
    end

    def parse_channel_expiration(expiration)
      return nil if expiration.blank?

      Time.at(expiration.to_i / 1000)
    end
  end
end
