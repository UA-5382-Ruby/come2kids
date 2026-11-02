# Unified error format { code, message, details } (US-1.3 will extend this).
module ErrorRendering
  extend ActiveSupport::Concern

  private

  def render_error(code, message, status:, details: [])
    render json: { code: code, message: message, details: details }, status: status
  end
end
