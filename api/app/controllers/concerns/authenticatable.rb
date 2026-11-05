# Resolves the current user from an "Authorization: Bearer <access token>" header.
# Controllers opt in with `before_action :authenticate_user!`.
module Authenticatable
  extend ActiveSupport::Concern

  private

  attr_reader :current_user

  def authenticate_user!
    token = bearer_token
    return render_unauthorized if token.blank?

    user = User.find_by(id: JwtService.decode(token)["sub"])
    return render_unauthorized unless account_usable?(user)
    return render_user_blocked(user) if user.blocked_at.present?

    @current_user = user
  rescue JwtService::ExpiredToken => e
    render_error(code: Api::ErrorCodes::TOKEN_EXPIRED, message: e.message, status: :unauthorized)
  rescue JwtService::InvalidToken => e
    render_unauthorized(e.message)
  end

  # Deactivated and soft-deleted accounts cannot authenticate at all.
  def account_usable?(user)
    user.present? && user.is_active? && user.deleted_at.nil?
  end

  def bearer_token
    scheme, token = request.authorization.to_s.split(" ", 2)
    token if scheme&.casecmp?("Bearer")
  end

  def render_unauthorized(message = "Authentication required")
    render_error(code: Api::ErrorCodes::UNAUTHORIZED, message: message, status: :unauthorized)
  end

  # FR-APP-1: the appeal token is issued in EPIC-6 (appeals).
  def render_user_blocked(user)
    render_error(code: Api::ErrorCodes::USER_BLOCKED, message: "Your account has been blocked",
      status: :forbidden, details: [ { field: "block_reason", message: user.block_reason } ])
  end
end
