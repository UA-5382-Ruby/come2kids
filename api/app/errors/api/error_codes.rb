# frozen_string_literal: true

module Api
  module ErrorCodes
    BAD_REQUEST = 'BAD_REQUEST'
    UNAUTHORIZED = 'UNAUTHORIZED'
    FORBIDDEN = 'FORBIDDEN'
    NOT_FOUND = 'NOT_FOUND'
    CONFLICT = 'CONFLICT'
    VALIDATION_FAILED = 'VALIDATION_FAILED'
    TOO_MANY_REQUESTS = 'TOO_MANY_REQUESTS'
    INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR'

    # Authentication (US-2.2)
    INVALID_CREDENTIALS = 'INVALID_CREDENTIALS'
    TOKEN_EXPIRED = 'TOKEN_EXPIRED'
    EMAIL_NOT_CONFIRMED = 'EMAIL_NOT_CONFIRMED'
    USER_BLOCKED = 'USER_BLOCKED'

    HTTP_STATUSES = {
      BAD_REQUEST => :bad_request,
      UNAUTHORIZED => :unauthorized,
      FORBIDDEN => :forbidden,
      NOT_FOUND => :not_found,
      CONFLICT => :conflict,
      VALIDATION_FAILED => :unprocessable_entity,
      TOO_MANY_REQUESTS => :too_many_requests,
      INTERNAL_SERVER_ERROR => :internal_server_error,
      INVALID_CREDENTIALS => :unauthorized,
      TOKEN_EXPIRED => :unauthorized,
      EMAIL_NOT_CONFIRMED => :forbidden,
      USER_BLOCKED => :forbidden
    }.freeze
  end
end
