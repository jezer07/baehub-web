# config/initializers/cors.rb
# Configure CORS for mobile API access

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In production, replace '*' with your mobile app's domain or origins
    # For development and testing, '*' allows all origins
    origins "*"

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false,
      expose: [ "Authorization" ]
  end
end
