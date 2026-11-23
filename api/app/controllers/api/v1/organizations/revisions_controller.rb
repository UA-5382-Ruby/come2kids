# frozen_string_literal: true

module Api
  module V1
    module Organizations
      class RevisionsController < ApplicationController
        before_action :authenticate_user!

        def destroy
          event = Organization.find(params[:organization_id]).events.find(params[:event_id])
          authorize event, :revise?

          result = ::Events::Revisions::Withdraw.call(event: event)
          raise ActiveRecord::RecordNotFound if result.failure?

          head :no_content
        end
      end
    end
  end
end
