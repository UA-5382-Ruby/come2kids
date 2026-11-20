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
          if event.published?
            authorize event, :revise?
            result = ::Events::Revisions::Upsert.call(event: event, actor: current_user, attributes: event_params)
            return render_record_errors(result.failure) if result.failure?

            render_resource(result.value!, blueprint: Api::EventRevisionBlueprint)
          else
            authorize event, :update?
            result = ::Events::UpdateDraft.call(event: event, attributes: event_params)
            if result.success?
              render_resource(result.value!, blueprint: Api::EventBlueprint, view: :managed)
            else
              render_record_errors(result.failure)
            end
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

        def destroy
          event = find_event
          raise ActiveRecord::RecordNotFound if event.deleted_at.present?

          authorize event, :destroy?
          result = ::Events::DeleteOrCancel.call(event: event, actor: current_user)
          return head :no_content if result.success?

          render_record_errors(result.failure)
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
            ticket_types: %i[id name price total_quantity sale_start_at sale_end_at],
            images: %i[id kind position]
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
