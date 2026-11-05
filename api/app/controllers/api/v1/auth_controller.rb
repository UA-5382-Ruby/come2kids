# Login (US-2.2). Returns a short-lived JWT access token in the body; there is no refresh token,
# so the client logs in again when the token expires and "logs out" by discarding it.
module Api
  module V1
    class AuthController < ApplicationController
      rate_limit to: 5, within: 1.minute, only: :login, name: "login-by-email",
        by: -> { "#{request.remote_ip}:#{params[:email].to_s.strip.downcase}" },
        with: -> { render_too_many_requests }
      rate_limit to: 20, within: 1.minute, only: :login, name: "login-by-ip",
        with: -> { render_too_many_requests }

      def login
        email = params[:email].to_s.strip.downcase
        password = params[:password].to_s
        return render_missing_credentials(email, password) if email.blank? || password.blank?

        # authenticate_by takes the same time whether or not the email exists.
        user = User.authenticate_by(email: email, password: password)
        return render_error("INVALID_CREDENTIALS", "Invalid email or password", status: :unauthorized) unless account_usable?(user)
        return render_error("EMAIL_NOT_CONFIRMED", "Please confirm your email first", status: :forbidden) unless user.is_email_confirmed?
        return render_user_blocked(user) if user.blocked_at.present?

        render json: {
          access_token: JwtService.encode(user),
          token_type: "Bearer",
          expires_in: JwtService::ACCESS_TTL.to_i
        }, status: :ok
      end

      private

      def render_missing_credentials(email, password)
        details = []
        details << { field: "email", message: "can't be blank" } if email.blank?
        details << { field: "password", message: "can't be blank" } if password.blank?
        render_error("VALIDATION_ERROR", "Email and password are required", status: :unprocessable_content, details: details)
      end

      def render_too_many_requests
        render_error("TOO_MANY_REQUESTS", "Too many attempts, please try again later", status: :too_many_requests)
      end
    end
  end
end
