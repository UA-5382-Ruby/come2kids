# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # Organization queue and decisions (US-6.1), block and unblock (US-6.4).
      class OrganizationsController < BaseController
        SORTABLE = { 'created_at' => :created_at, 'updated_at' => :updated_at }.freeze

        before_action :load_organization, except: :index

        # GET /api/v1/moderation/organizations?status=pending_approval
        def index
          authorize [ :moderation, Organization ]
          status = queue_status(Organization::STATUSES, default: 'pending_approval',
                                                        aliases: { 'pending' => 'pending_approval' })
          relation = filter_by_status(Organization.includes(:organization_translations, :owner), status)
          records, pagination = paginate_collection(relation, sortable: SORTABLE, filterable: { city: :city })

          render_collection(records, blueprint: Api::ModerationOrganizationBlueprint, pagination: pagination)
        end

        def approve
          decide('approved')
        end

        def reject
          decide('rejected')
        end

        def block
          authorize [ :moderation, @organization ], :block?
          render_organization(::Moderation::BlockOrganization.call(organization: @organization,
                                                                   moderator: current_user, reason: reason_param))
        end

        def unblock
          authorize [ :moderation, @organization ], :block?
          render_organization(::Moderation::UnblockOrganization.call(organization: @organization,
                                                                     moderator: current_user, reason: reason_param))
        end

        private

        def load_organization
          @organization = Organization.find(params[:id])
        end

        def decide(decision)
          authorize [ :moderation, @organization ], :decide?
          render_organization(::Moderation::DecideOrganization.call(organization: @organization,
                                                                    moderator: current_user,
                                                                    decision: decision, reason: reason_param))
        end

        def render_organization(result)
          render_result(result, blueprint: Api::ModerationOrganizationBlueprint)
        end
      end
    end
  end
end
