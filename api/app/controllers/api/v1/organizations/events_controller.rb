# frozen_string_literal: true

module Api
  module V1
    module Organizations
      class EventsController < ApplicationController
        before_action :authenticate_user!

        SORTABLE = { 'created' => 'events.created_at', 'date' => 'events.start_at' }.freeze

        def index
          organization = Organization.find(params[:organization_id])
          authorize organization.events.build, :index?
          reject_unknown_status

          params[:sort] = 'created' if params[:sort].blank?
          params[:direction] = 'desc' if params[:direction].blank? && params[:sort] == 'created'
          records, pagination = paginate_collection(organizer_events(organization), sortable: SORTABLE, default_sort: 'created')
          render_collection(records, blueprint: Api::EventBlueprint, pagination: pagination, view: :organizer)
        end

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

        private

        def find_event
          Organization.find(params[:organization_id]).events.find(params[:id])
        end

        def organizer_events(organization)
          relation = organization.events.includes(
            :pending_revision, :event_translations, :ticket_types, :category,
            organization: :organization_translations
          )
          relation = relation.where(deleted_at: nil) unless include_deleted?
          relation = relation.where(status: params[:status]) if params[:status].present?
          relation
        end

        def include_deleted?
          ActiveModel::Type::Boolean.new.cast(params[:include_deleted])
        end

        def reject_unknown_status
          return if params[:status].blank? || Event::STATUSES.include?(params[:status])

          invalid_query_parameter(:status, 'is not a valid status')
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
