# frozen_string_literal: true

# Resolves the current user from an "Authorization: Bearer <token>" header.
# Controllers opt in with `before_action :authenticate_user!`, or with `before_action :authenticate_user`
# on endpoints that guests may also call. The appeal endpoints use `authenticate_appellant!`, which also
# accepts the appeal token a blocked user receives at login (FR-APP-1).
module Authenticatable
  extend ActiveSupport::Concern

  private

  attr_reader :current_user

  # Optional authentication: without an Authorization header the request is a guest
  # (current_user stays nil). A header that is sent must still be a valid token, otherwise 401.
  def authenticate_user
    authenticate_user! if request.authorization.present?
  end

  def authenticate_user!
    authenticate_with_scopes([ JwtService::ACCESS_SCOPE ])
  end

  # A blocked user authenticates with the appeal token; everybody else (e.g. the owner of a blocked
  # organization, who is not blocked) uses a normal access token.
  def authenticate_appellant!
    authenticate_with_scopes([ JwtService::ACCESS_SCOPE, JwtService::APPEAL_SCOPE ])
  end

  def authenticate_with_scopes(allowed_scopes)
    token = bearer_token
    return render_unauthorized if token.blank?

    payload = JwtService.decode(token)
    scope = JwtService.scope_of(payload)
    return render_appeal_token_scope unless allowed_scopes.include?(scope)

    user = User.find_by(id: payload['sub'])
    return render_unauthorized unless account_usable?(user)
    # Access tokens of a blocked user stop working at once (FR-MOD-4); the appeal token is meant for them.
    return render_user_blocked(user) if user.blocked? && scope == JwtService::ACCESS_SCOPE

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
    scheme, token = request.authorization.to_s.split(' ', 2)
    token if scheme&.casecmp?('Bearer')
  end

  def render_unauthorized(message = 'Authentication required')
    render_error(code: Api::ErrorCodes::UNAUTHORIZED, message: message, status: :unauthorized)
  end

  def render_appeal_token_scope
    render_error(code: Api::ErrorCodes::APPEAL_TOKEN_SCOPE, message: I18n.t('moderation.errors.appeal_token_scope'),
      status: :forbidden)
  end

  # FR-APP-1: at login a blocked user also gets an appeal token (appeal_token:), which opens only the
  # appeal endpoints. The other keys keep the usual error format.
  def render_user_blocked(user, appeal_token: nil)
    body = { code: Api::ErrorCodes::USER_BLOCKED, message: I18n.t('moderation.errors.user_blocked'),
             details: [ { field: 'block_reason', message: user.block_reason } ] }
    if appeal_token
      body[:appeal_token] = appeal_token
      body[:appeal_token_expires_in] = JwtService::APPEAL_TTL.to_i
    end
    render json: body, status: :forbidden
  end
end
