# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Api::QueryParameters
  include Api::ResponseFormat
  include Authenticatable

  rescue_from StandardError, with: :render_internal_server_error
  rescue_from Api::ApplicationError, with: :render_application_error
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActionController::BadRequest, with: :render_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
  rescue_from ActiveRecord::RecordNotSaved, with: :render_validation_error

  # Must come after `rescue_from StandardError`: Rails checks the handlers declared last first,
  # so Pundit errors reach Authorizable instead of becoming a 500.
  include Authorizable

  private

  def render_application_error(error)
    render_error(
      code: error.code,
      message: error.message,
      details: error.details,
      status: error.status
    )
  end

  def render_bad_request(error)
    render_error(
      code: Api::ErrorCodes::BAD_REQUEST,
      message: error.message,
      status: :bad_request
    )
  end

  def render_not_found(error)
    render_error(
      code: Api::ErrorCodes::NOT_FOUND,
      message: error.message,
      status: :not_found
    )
  end

  def render_validation_error(error)
    details = error.record&.errors&.map do |validation_error|
      {
        field: validation_error.attribute.to_s,
        message: validation_error.message
      }
    end || []

    render_error(
      code: Api::ErrorCodes::VALIDATION_FAILED,
      message: 'The request is invalid.',
      details: details,
      status: :unprocessable_entity
    )
  end

  def render_internal_server_error(error)
    Rails.logger.error("#{error.class}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace

    render_error(
      code: Api::ErrorCodes::INTERNAL_SERVER_ERROR,
      message: 'An unexpected error occurred.',
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
end
