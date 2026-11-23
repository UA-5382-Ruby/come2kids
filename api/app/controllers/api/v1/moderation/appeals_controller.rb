# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # The separate appeal queue for moderators (US-6.5, FR-APP-5, FR-APP-6).
      class AppealsController < BaseController
        SORTABLE = { 'created_at' => :created_at, 'reviewed_at' => :reviewed_at }.freeze

        before_action :load_appeal, except: :index

        # GET /api/v1/moderation/appeals?status=open&target_type=User
        def index
          authorize [ :moderation, Appeal ]
          status = queue_status(Appeal::STATUSES, default: 'open')
          relation = filter_by_status(Appeal.includes(:submitted_by, :target), status)
          records, pagination = paginate_collection(relation, sortable: SORTABLE,
                                                              filterable: { target_type: :target_type })

          render_collection(records, blueprint: Api::AppealBlueprint, pagination: pagination, view: :moderator)
        end

        def show
          authorize [ :moderation, @appeal ]
          render_appeal
        end

        def accept
          decide('accepted')
        end

        def reject
          decide('rejected')
        end

        private

        def load_appeal
          @appeal = Appeal.find(params[:id])
        end

        def decide(decision)
          authorize [ :moderation, @appeal ], :decide?
          result = ::Appeals::Decide.call(appeal: @appeal, moderator: current_user, decision: decision,
                                          reason: reason_param)
          render_result(result, blueprint: Api::AppealBlueprint, view: :moderator)
        end

        def render_appeal
          render_resource(@appeal, blueprint: Api::AppealBlueprint, view: :moderator)
        end
      end
    end
  end
end
