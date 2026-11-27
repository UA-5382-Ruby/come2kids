# frozen_string_literal: true

module Api
  module V1
    module Organizations
      module Events
        class CheckInStatisticsController < ApplicationController
          before_action :authenticate_user!

          def show
            event = Event.where(organization_id: params[:organization_id]).find(params[:event_id])
            authorize event, :check_in_statistics?

            result = Tickets::CheckInStatistics.call(event: event)
            raise result.failure if result.failure?

            render_resource result.value!, blueprint: Api::CheckInStatisticsBlueprint
          end
        end
      end
    end
  end
end
