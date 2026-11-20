# frozen_string_literal: true

module Api
  module V1
    module Organizations
      class EventsController < ApplicationController
        before_action :authenticate_user!

        def create
          organization = Organization.find(params[:organization_id])
          event = organization.events.build
          authorize event

          result = ::Events::CreateDraft.call(
            organization: organization,
            author: current_user,
            attributes: event_params
          )

          if result.success?
            render_resource(result.value!, blueprint: Api::EventBlueprint, status: :created, view: :managed)
          else
            render_record_errors(result.failure)
          end
        end

        def update
          event = find_event
          authorize event, :update?

          result = ::Events::UpdateDraft.call(event: event, attributes: event_params)
          if result.success?
            render_resource(result.value!, blueprint: Api::EventBlueprint, view: :managed)
          else
            render_record_errors(result.failure)
          end
        end

        def submit
          event = find_event
          authorize event, :submit?

          result = ::Events::Submit.call(event: event, actor: current_user)
          if result.success?
            render_resource(result.value!, blueprint: Api::EventBlueprint, view: :managed)
          else
            render_record_errors(result.failure)
          end
        end

        private

        def find_event
          Organization.find(params[:organization_id]).events.find(params[:id])
        end

        def event_params
          event = params[:event]
          return {} if event.blank?

          event.permit(
            :category_id, :start_at, :end_at, :time_zone, :location_type,
            :address, :city, :online_url,
            translations: %i[locale title description],
            ticket_types: %i[name price total_quantity sale_start_at sale_end_at]
          )
        end

        def render_record_errors(record)
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
