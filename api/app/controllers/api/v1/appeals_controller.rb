# frozen_string_literal: true

module Api
  module V1
    # Appeals of blocked users and organization owners (US-6.5, FR-APP-1..4, FR-APP-7).
    #
    # A blocked user authenticates with the appeal token returned by the login endpoint; the owner of a
    # blocked organization uses a normal access token and passes `organization_id`.
    class AppealsController < ApplicationController
      before_action :authenticate_appellant!
      before_action :load_target

      # POST /api/v1/appeals { message, organization_id? }
      def create
        authorize Appeal.new(target: @target, submitted_by: current_user)
        result = ::Appeals::Submit.call(user: current_user, target: @target, message: params[:message])

        render_result(result, blueprint: Api::AppealBlueprint, status: :created)
      end

      # GET /api/v1/appeals/current?organization_id=
      # The block, the latest appeal with its decision, and when a new appeal is allowed.
      def current
        authorize Appeal.new(target: @target, submitted_by: current_user), :current?

        render json: { data: current_status }
      end

      private

      def load_target
        @target = params[:organization_id].present? ? Organization.find(params[:organization_id]) : current_user
      end

      def current_status
        latest = Appeal.for_target(@target).order(created_at: :desc, id: :desc).first
        next_allowed_at = Appeal.next_allowed_at(@target)
        {
          target_type: @target.class.name,
          target_id: @target.id,
          blocked: @target.blocked?,
          block_reason: @target.block_reason,
          blocked_at: Api::ModerationFields.time(@target.blocked_at),
          appeal: latest && Api::AppealBlueprint.render_as_hash(latest),
          can_submit: @target.blocked? && !latest&.open? && next_allowed_at.nil?,
          next_appeal_allowed_at: next_allowed_at&.utc&.iso8601
        }
      end
    end
  end
end
