# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # Queue of edits of published events and decisions on them (US-6.2, FR-MOD-6).
      class EventRevisionsController < BaseController
        SORTABLE = { 'created_at' => :created_at, 'updated_at' => :updated_at }.freeze
        FILTERABLE = { event_id: :event_id }.freeze
        PRELOAD = [
          :submitted_by,
          { event: [ :event_translations, :ticket_types, { event_media: { file_attachment: :blob } },
                     { organization: :organization_translations } ] }
        ].freeze

        # GET /api/v1/moderation/event-revisions?status=under_review
        def index
          authorize [ :moderation, EventRevision ]
          status = queue_status(EventRevision::STATUSES, default: 'under_review')
          relation = EventRevision.includes(*PRELOAD)
          records, pagination = paginate_collection(filter_by_status(relation, status),
                                                    sortable: SORTABLE, filterable: FILTERABLE)

          render_collection(records, blueprint: Api::ModerationEventRevisionBlueprint, pagination: pagination)
        end

        def approve
          decide('approved')
        end

        def reject
          decide('rejected')
        end

        private

        def decide(decision)
          revision = EventRevision.find(params[:id])
          authorize [ :moderation, revision ], :decide?
          result = ::Moderation::DecideRevision.call(revision: revision, moderator: current_user, decision: decision,
                                                     reason: reason_param)
          render_result(result, blueprint: Api::ModerationEventRevisionBlueprint)
        end
      end
    end
  end
end
