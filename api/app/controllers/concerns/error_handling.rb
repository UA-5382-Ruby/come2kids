module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from ApiError, with: :render_api_error
  end

  private

  def render_api_error(exception)
    # I18n.locale вже встановлено правильно через before_action
    render json: {
      code: exception.code,
      message: I18n.t("api_errors.#{exception.code.downcase}", default: exception.code.humanize),
      details: exception.details
    }, status: exception.status
  end

  def render_record_invalid(exception)
    render json: {
      code: "VALIDATION_ERROR",
      message: I18n.t("api_errors.validation_error"),
      details: exception.record.errors.map do |error|
        {
          field: error.attribute,
          error: error.type,
          message: error.full_message
        }
      end
    }, status: :unprocessable_entity
  end

  def render_parameter_missing(exception)
    render json: {
      code: "PARAMETER_MISSING",
      message: I18n.t("api_errors.parameter_missing"),
      details: [ { field: exception.param.to_s, error: "missing", message: "is required" } ]
    }, status: :bad_request
  end
end
