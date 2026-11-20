# frozen_string_literal: true

module Api
  module V1
    module Organizations
      class ImagesController < ApplicationController
        before_action :authenticate_user!

        def create
          event = find_event
          authorize event, :manage_media?
          result = ::Events::Media::Upload.call(event: event, upload: params[:image], kind: params[:kind])
          return render_media_errors(result.failure) if result.failure?

          render_resource(result.value!, blueprint: Api::EventMediaBlueprint, status: :created)
        end

        def order
          event = find_event
          authorize event, :manage_media?
          result = ::Events::Media::Reorder.call(event: event, image_ids: image_ids)
          return render_media_errors(result.failure) if result.failure?

          render json: { data: Api::EventMediaBlueprint.render_as_hash(result.value!) }
        end

        def destroy
          event = find_event
          authorize event, :manage_media?
          result = ::Events::Media::Destroy.call(media: event.event_media.find(params[:id]))
          return render_media_errors(result.failure) if result.failure?

          head :no_content
        end

        private

        def find_event
          Organization.find(params[:organization_id]).events.find(params[:event_id])
        end

        def image_ids
          params.permit(image_ids: [])[:image_ids] || []
        end

        def render_media_errors(record)
          details = record.errors.map do |validation_error|
            {
              field: validation_error.attribute.to_s,
              error: validation_error.type.to_s,
              message: validation_error.full_message
            }
          end

          render_error(
            code: 'VALIDATION_ERROR',
            message: I18n.t('api_errors.validation_error', default: 'Validation failed'),
            details: details,
            status: :unprocessable_entity
          )
        end
      end
    end
  end
end
