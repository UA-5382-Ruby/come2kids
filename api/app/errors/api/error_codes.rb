module Api
  module ErrorCodes
    BAD_REQUEST = "BAD_REQUEST"
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    NOT_FOUND = "NOT_FOUND"
    CONFLICT = "CONFLICT"
    VALIDATION_FAILED = "VALIDATION_FAILED"
    TOO_MANY_REQUESTS = "TOO_MANY_REQUESTS"
    INTERNAL_SERVER_ERROR = "INTERNAL_SERVER_ERROR"

    HTTP_STATUSES = {
      BAD_REQUEST => :bad_request,
      UNAUTHORIZED => :unauthorized,
      FORBIDDEN => :forbidden,
      NOT_FOUND => :not_found,
      CONFLICT => :conflict,
      VALIDATION_FAILED => :unprocessable_entity,
      TOO_MANY_REQUESTS => :too_many_requests,
      INTERNAL_SERVER_ERROR => :internal_server_error
    }.freeze
  end
end
