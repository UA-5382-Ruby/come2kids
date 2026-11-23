# frozen_string_literal: true

module Api
  module ResponseFormat
    private

    def render_resource(resource, blueprint:, status: :ok, view: :default)
      render json: {
        data: blueprint.render_as_hash(resource, view: view)
      }, status: status
    end

    # Renders the value of a successful Dry::Monads::Result. A Failure is raised, as in MailDeliveryJob,
    # so ErrorHandling turns it into the usual { code, message, details } response.
    def render_result(result, **)
      raise result.failure if result.failure?

      render_resource(result.value!, **)
    end

    def render_collection(resources, blueprint:, pagination:, status: :ok, view: :default)
      render json: {
        data: blueprint.render_as_hash(resources, view: view),
        pagination: pagination
      }, status: status
    end
  end
end
