# Login, token refresh and logout (US-2.2, FR-AUTH-4).
# The access token is returned in the body; the refresh token only travels in an
# HttpOnly cookie scoped to /auth, so frontend JavaScript can never read it.
class AuthController < ApplicationController
  REFRESH_COOKIE = :refresh_token
  REFRESH_COOKIE_PATH = "/auth".freeze
  # A cross-site form cannot set custom headers without a CORS preflight (CSRF defence).
  CSRF_HEADER = "X-Requested-With".freeze

  rate_limit to: 5, within: 1.minute, only: :login, name: "login-by-email",
    by: -> { "#{request.remote_ip}:#{params[:email].to_s.strip.downcase}" },
    with: -> { render_too_many_requests }
  rate_limit to: 20, within: 1.minute, only: :login, name: "login-by-ip",
    with: -> { render_too_many_requests }
  rate_limit to: 30, within: 1.minute, only: :refresh, name: "refresh-by-ip",
    with: -> { render_too_many_requests }

  before_action :require_csrf_header, only: %i[refresh logout]

  def login
    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s
    return render_missing_credentials(email, password) if email.blank? || password.blank?

    # authenticate_by takes the same time whether or not the email exists.
    user = User.authenticate_by(email: email, password: password)
    return render_error("INVALID_CREDENTIALS", "Invalid email or password", status: :unauthorized) unless account_usable?(user)
    return render_error("EMAIL_NOT_CONFIRMED", "Please confirm your email first", status: :forbidden) unless user.is_email_confirmed?
    return render_user_blocked(user) if user.blocked_at.present?

    _record, raw_token = RefreshToken.issue_for(user)
    render_tokens(user, raw_token)
  end

  def refresh
    token = RefreshToken.find_by_raw(cookies[REFRESH_COOKIE])
    return render_invalid_refresh_token if token.nil? || token.expired?

    user = token.user
    if token.revoked?
      # Reuse of a rotated token means it was probably stolen: end every session.
      RefreshToken.revoke_all_for(user)
      return render_invalid_refresh_token
    end

    unless account_usable?(user)
      RefreshToken.revoke_all_for(user)
      return render_invalid_refresh_token
    end

    if user.blocked_at.present?
      RefreshToken.revoke_all_for(user)
      delete_refresh_cookie
      return render_user_blocked(user)
    end

    rotated = token.rotate!
    return render_invalid_refresh_token if rotated.nil?

    render_tokens(user, rotated.last)
  end

  def logout
    token = RefreshToken.find_by_raw(cookies[REFRESH_COOKIE])
    token.revoke! if token && !token.revoked?
    delete_refresh_cookie
    head :no_content
  end

  private

  def render_tokens(user, raw_refresh_token)
    cookies[REFRESH_COOKIE] = {
      value: raw_refresh_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      path: REFRESH_COOKIE_PATH,
      expires: RefreshToken.ttl.from_now
    }
    render json: {
      access_token: JwtService.encode(user),
      token_type: "Bearer",
      expires_in: JwtService.access_ttl.to_i
    }, status: :ok
  end

  def delete_refresh_cookie
    cookies.delete(REFRESH_COOKIE, path: REFRESH_COOKIE_PATH)
  end

  def require_csrf_header
    return if request.headers[CSRF_HEADER].present?

    render_error("CSRF_HEADER_MISSING", "#{CSRF_HEADER} header is required", status: :forbidden)
  end

  def render_invalid_refresh_token
    delete_refresh_cookie
    render_error("INVALID_REFRESH_TOKEN", "Refresh token is invalid or expired", status: :unauthorized)
  end

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
