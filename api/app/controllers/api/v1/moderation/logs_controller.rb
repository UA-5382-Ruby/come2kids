# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # Moderation decisions (FR-MOD-3): who decided what, when and why.
      class LogsController < BaseController
        FILTERABLE = { entity_type: :entity_type, entity_id: :entity_id, moderator_id: :moderator_id,
                       decision: :decision }.freeze

        # GET /api/v1/moderation/logs?entity_type=Organization&entity_id=5
        def index
          authorize [ :moderation, ModerationLog ]
          records, pagination = paginate_collection(ModerationLog.all, sortable: { 'created_at' => :created_at },
                                                                       filterable: FILTERABLE)

          render_collection(records, blueprint: Api::ModerationLogBlueprint, pagination: pagination)
        end
      end
    end
  end
end
