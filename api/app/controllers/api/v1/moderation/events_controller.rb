# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # Queue of new events and decisions on them (US-6.2).
      class EventsController < BaseController
        SORTABLE = { 'submitted_at' => :submitted_at, 'created_at' => :created_at, 'start_at' => :start_at }.freeze
        FILTERABLE = { organization_id: :organization_id, category_id: :category_id }.freeze

        # GET /api/v1/moderation/events?status=under_review
        def index
          authorize [ :moderation, Event ]
          status = queue_status(Event::STATUSES, default: 'under_review')
          relation = Event.includes(:event_translations, :created_by, organization: :organization_translations)
          records, pagination = paginate_collection(filter_by_status(relation, status),
                                                    sortable: SORTABLE, filterable: FILTERABLE)

          render_collection(records, blueprint: Api::ModerationEventBlueprint, pagination: pagination)
        end

        def approve
          decide('approved')
        end

        def reject
          decide('rejected')
        end

        private

        def decide(decision)
          event = Event.find(params[:id])
          authorize [ :moderation, event ], :decide?
          result = ::Moderation::DecideEvent.call(event: event, moderator: current_user, decision: decision,
                                                  reason: reason_param)
          render_result(result, blueprint: Api::ModerationEventBlueprint)
        end
      end
    end
  end
end
