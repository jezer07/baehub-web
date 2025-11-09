# app/services/json_web_token.rb
class JsonWebToken
  # Secret key for JWT encoding/decoding
  SECRET_KEY = Rails.application.credentials.secret_key_base

  # JWT expiration time (short-lived for security)
  JWT_EXPIRATION = 1.hour

  # Encode a payload into a JWT token
  def self.encode(payload, exp = JWT_EXPIRATION.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  # Decode a JWT token and return the payload
  def self.decode(token)
    body = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(body)
  rescue JWT::ExpiredSignature, JWT::DecodeError => e
    Rails.logger.error("JWT Decode Error: #{e.message}")
    nil
  end
end
