# frozen_string_literal: true

module Api
  module ResponseFormat
    private

    def render_resource(resource, blueprint:, status: :ok)
      render json: {
        data: blueprint.render_as_hash(resource)
      }, status: status
    end

    def render_collection(resources, blueprint:, pagination:, status: :ok)
      render json: {
        data: blueprint.render_as_hash(resources),
        pagination: pagination
      }, status: status
    end
  end
end
