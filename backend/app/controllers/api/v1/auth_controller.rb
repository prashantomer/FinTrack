module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :login ]

      def login
        user = User.find_by(email: params[:email])
        if user&.authenticate(params[:password])
          token = JsonWebToken.encode(user_id: user.id)
          render_success(data: { access_token: token, token_type: "bearer", user: UserSerializer.one(user) })
        else
          render_error(message: "Invalid email or password", status: :unauthorized)
        end
      end

      def me
        render_success(data: current_user)
      end

      def update_me
        if current_user.update(user_update_params)
          render_success(data: current_user)
        else
          render_error(message: "Validation failed", errors: current_user.errors.to_hash)
        end
      end

      private

      def user_update_params
        params.permit(:full_name, :email, :password, :currency_code, :currency_locale)
      end
    end
  end
end
