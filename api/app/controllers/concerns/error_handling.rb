module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :render_internal_server_error
    rescue_from Api::ApplicationError, with: :render_application_error
    rescue_from ApiError, with: :render_api_error
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from ActionController::BadRequest, with: :render_bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActiveRecord::RecordNotSaved, with: :render_validation_error
  end

  private

  def render_application_error(error)
    render_error(
      code: error.code,
      message: error.message,
      details: error.details || [],
      status: error.status || :internal_server_error
    )
  end

  def render_bad_request(error)
    param_name = error.respond_to?(:param) ? error.param.to_s : "unknown"

    render_error(
      code: "PARAMETER_MISSING",
      message: I18n.t("api_errors.parameter_missing", default: "Bad request"),
      details: [ {
                  field: param_name,
                  error: "missing",
                  message: I18n.t("api_errors.is_required", default: "is required")
                } ],
      status: :bad_request
    )
  end

  def render_api_error(error)
    code = error.message

    default_msg = case code
    when "TOKEN_INVALID" then "The token is invalid or has expired."
    when "TOKEN_USED" then "This token has already been used."
    else "Invalid request"
    end

    message = I18n.t("api_errors.#{code.downcase}", default: default_msg)

    render_error(
      code: code,
      message: message,
      status: :unprocessable_entity
    )
  end

  def render_not_found(error)
    render_error(
      code: "NOT_FOUND",
      message: error.message || I18n.t("api_errors.not_found", default: "Record not found"),
      status: :not_found
    )
  end

  def render_validation_error(error)
    details = error.record&.errors&.map do |validation_error|
      {
        field: validation_error.attribute.to_s,
        error: validation_error.type.to_s,
        message: validation_error.full_message # Rails автоматично перекладає full_message через I18n
      }
    end || []

    render_error(
      code: "VALIDATION_ERROR",
      message: I18n.t("api_errors.validation_error", default: "Validation failed"),
      details: details,
      status: :unprocessable_entity
    )
  end

  def render_internal_server_error(error)
    Rails.logger.error("#{error.class}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace

    render_error(
      code: "INTERNAL_SERVER_ERROR",
      message: I18n.t("api_errors.internal_server_error", default: "An unexpected error occurred."),
      status: :internal_server_error
    )
  end

  def render_error(code:, message:, status:, details: [])
    render json: {
      code: code,
      message: message,
      details: details
    }, status: status
  end

  public :render_error
end
