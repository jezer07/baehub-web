# app/controllers/api/base_controller.rb
module Api
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate_api_user!

    attr_reader :current_user, :current_api_token

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request

    private

    def authenticate_api_user!
      authenticate_with_http_token do |token, options|
        # Decode JWT token
        decoded_token = JsonWebToken.decode(token)

        if decoded_token
          @current_user = User.find_by(id: decoded_token[:user_id])
          @current_api_token = ApiToken.find_by(token: decoded_token[:token_id])

          if @current_user && @current_api_token&.active?
            @current_api_token.touch_last_used!
            return true
          end
        end
      end

      render json: { error: "Unauthorized" }, status: :unauthorized
    end

    def render_error(message, status = :unprocessable_entity)
      render json: { error: message }, status: status
    end

    def render_errors(errors, status = :unprocessable_entity)
      render json: { errors: errors }, status: status
    end

    # Exception handlers
    def not_found(exception)
      render json: { error: exception.message }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
    end

    def bad_request(exception)
      render json: { error: exception.message }, status: :bad_request
    end
  end
end
