require "net/http"
require "uri"
require "json"

module GoogleCalendar
  # Zeitwerk maps oauth.rb -> Oauth, so keep the constant name conventional.
  class Oauth
    AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URL = "https://oauth2.googleapis.com/token"
    SCOPE = "https://www.googleapis.com/auth/calendar".freeze

    def self.authorization_url(redirect_uri:, state:)
      uri = URI(AUTH_URL)
      uri.query = URI.encode_www_form(
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: SCOPE,
        access_type: "offline",
        include_granted_scopes: "true",
        prompt: "consent",
        state: state
      )
      uri.to_s
    end

    def self.exchange_code(code:, redirect_uri:)
      uri = URI(TOKEN_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      GoogleCalendar::Tls.configure(http)

      request = Net::HTTP::Post.new(uri)
      request.set_form_data({
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        code: code,
        grant_type: "authorization_code",
        redirect_uri: redirect_uri
      })

      response = http.request(request)

      data = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        error = data["error_description"] || data["error"] || "OAuth token exchange failed"
        raise GoogleCalendar::RequestError.new(error, response.code)
      end

      {
        access_token: data.fetch("access_token"),
        refresh_token: data["refresh_token"],
        expires_in: data["expires_in"].to_i
      }
    end
  end
end
