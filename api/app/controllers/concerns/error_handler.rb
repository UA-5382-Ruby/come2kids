module ErrorHandler
    extend ActiveSupport::Concern
    included do
       # Handlers declared later take precedence, so the generic one goes first.
       rescue_from StandardError,                                with: :handle_internal
       rescue_from Api::Error,                                   with: :handle_api_error
       rescue_from ActiveRecord::RecordNotFound,                 with: :handle_not_found
       rescue_from ActiveRecord::RecordInvalid,                  with: :handle_validation
       rescue_from ActionController::ParameterMissing,           with: :handle_param_missing
       rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_bad_json
    end

    private

    def render_error(code, message: nil, details: {})
       err = Api::Error.new(code, message: message, details: details)
       render json: { code: err.code, message: err.message, details: err.details }, status: err.status
    end

    def handle_api_error(e)     = render_error(e.code, message: e.message, details: e.details)
    def handle_not_found(e)     = render_error(:not_found, details: { resource: e.model })
    def handle_param_missing(e) = render_error(:bad_request, message: e.message, details: { param: e.param })
    def handle_bad_json(_e)     = render_error(:bad_request, message: "Malformed request body")

    def handle_validation(e)
       render_error(:validation_failed, details: { fields: e.record.errors.to_hash })
    end

    def handle_internal(e)
       Rails.logger.error("#{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
       render_error(:internal_error) # never leak internals
    end
end