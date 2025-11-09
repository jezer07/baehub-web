# app/controllers/api/v1/auth_controller.rb
module Api
  module V1
    class AuthController < ActionController::API
      skip_before_action :verify_authenticity_token, raise: false

      # POST /api/v1/auth/signup
      def signup
        user = User.new(signup_params)

        if user.save
          api_token = create_api_token(user)
          jwt_token = generate_jwt_token(user, api_token)

          render json: {
            user: user_response(user),
            token: jwt_token,
            refresh_token: api_token.token
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email])

        if user&.valid_password?(params[:password])
          api_token = create_api_token(user)
          jwt_token = generate_jwt_token(user, api_token)

          render json: {
            user: user_response(user),
            token: jwt_token,
            refresh_token: api_token.token
          }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        refresh_token = params[:refresh_token]
        api_token = ApiToken.active.find_by(token: refresh_token)

        if api_token
          jwt_token = generate_jwt_token(api_token.user, api_token)

          render json: {
            token: jwt_token,
            refresh_token: api_token.token
          }, status: :ok
        else
          render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        authenticate_with_http_token do |token, options|
          decoded_token = JsonWebToken.decode(token)

          if decoded_token
            api_token = ApiToken.find_by(token: decoded_token[:token_id])
            api_token&.destroy
          end
        end

        render json: { message: "Logged out successfully" }, status: :ok
      end

      private

      def signup_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :timezone, :preferred_color)
      end

      def create_api_token(user)
        user.api_tokens.create!(device_info: request.user_agent)
      end

      def generate_jwt_token(user, api_token)
        JsonWebToken.encode(
          user_id: user.id,
          token_id: api_token.token
        )
      end

      def user_response(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          timezone: user.timezone,
          preferred_color: user.preferred_color,
          avatar_url: user.avatar_url,
          prefers_dark_mode: user.prefers_dark_mode,
          role: user.role,
          solo_mode: user.solo_mode,
          coupled: user.paired?,
          couple_id: user.couple_id
        }
      end

      def authenticate_with_http_token(&block)
        return unless request.headers["Authorization"].present?

        strategy = ActionController::HttpAuthentication::Token
        strategy.authenticate(self, &block)
      end
    end
  end
end
