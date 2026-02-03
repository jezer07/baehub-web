require "net/http"
require "uri"
require "json"
require "cgi"

module GoogleCalendar
  class Client
    API_BASE = "https://www.googleapis.com/calendar/v3"
    TOKEN_URL = "https://oauth2.googleapis.com/token"

    def initialize(connection)
      @connection = connection
    end

    def list_calendars
      get_json("/users/me/calendarList")
    end

    def list_events(calendar_id, params = {})
      get_json("/calendars/#{escape(calendar_id)}/events", params)
    end

    def insert_event(calendar_id, payload)
      post_json("/calendars/#{escape(calendar_id)}/events", payload)
    end

    def update_event(calendar_id, event_id, payload)
      put_json("/calendars/#{escape(calendar_id)}/events/#{escape(event_id)}", payload)
    end

    def delete_event(calendar_id, event_id)
      delete_json("/calendars/#{escape(calendar_id)}/events/#{escape(event_id)}")
    end

    def watch_events(calendar_id, webhook_url, channel_id)
      body = {
        id: channel_id,
        type: "web_hook",
        address: webhook_url
      }
      post_json("/calendars/#{escape(calendar_id)}/events/watch", body)
    end

    def stop_channel(channel_id, resource_id)
      body = { id: channel_id, resourceId: resource_id }
      post_json("/channels/stop", body, base_url: API_BASE)
    end

    def refresh_access_token!
      return if @connection.refresh_token.blank?

      response = Net::HTTP.post_form(URI(TOKEN_URL), {
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        refresh_token: @connection.refresh_token,
        grant_type: "refresh_token"
      })
      data = JSON.parse(response.body)
      unless response.is_a?(Net::HTTPSuccess)
        error = data["error_description"] || data["error"] || "OAuth refresh failed"
        raise RequestError.new(error, response.code)
      end

      @connection.update!(
        access_token: data.fetch("access_token"),
        expires_at: Time.current + data.fetch("expires_in").to_i.seconds,
        refresh_token: data["refresh_token"].presence || @connection.refresh_token
      )
    end

    private

    def escape(value)
      CGI.escape(value.to_s)
    end

    def get_json(path, params = {})
      request(:get, path, params: params)
    end

    def post_json(path, body, base_url: API_BASE)
      request(:post, path, body: body, base_url: base_url)
    end

    def put_json(path, body)
      request(:put, path, body: body)
    end

    def delete_json(path)
      request(:delete, path)
    end

    def request(method, path, params: {}, body: nil, base_url: API_BASE, retried: false)
      refresh_access_token! if @connection.access_token_expired?

      uri = URI("#{base_url}#{path}")
      uri.query = URI.encode_www_form(params) if params.present?
      request = build_request(method, uri, body)
      request["Authorization"] = "Bearer #{@connection.access_token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.ssl_context = GoogleCalendar::TLS.ssl_context
        http.request(request)
      end

      if response.code.to_i == 401 && !retried
        refresh_access_token!
        return request(method, path, params: params, body: body, base_url: base_url, retried: true)
      end

      if response.body.blank?
        unless response.is_a?(Net::HTTPSuccess)
          raise RequestError.new("Google Calendar request failed", response.code)
        end
        return {}
      end

      data = JSON.parse(response.body)
      unless response.is_a?(Net::HTTPSuccess)
        error = data["error"]&.dig("message") || data["error"] || "Google Calendar request failed"
        raise RequestError.new(error, response.code)
      end

      data
    end

    def build_request(method, uri, body)
      case method
      when :get
        Net::HTTP::Get.new(uri)
      when :post
        req = Net::HTTP::Post.new(uri)
        attach_json_body(req, body)
      when :put
        req = Net::HTTP::Put.new(uri)
        attach_json_body(req, body)
      when :delete
        Net::HTTP::Delete.new(uri)
      else
        raise ArgumentError, "Unsupported request method: #{method}"
      end
    end

    def attach_json_body(request, body)
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      request
    end
  end
end
