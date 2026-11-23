# frozen_string_literal: true

module Api
  module V1
    module Organizations
      module Events
        class TicketsController < ApplicationController
          before_action :authenticate_user!

          def index
            event = Organization.find(params[:organization_id]).events.find(params[:event_id])
            authorize event, :participants?

            records, pagination = ::Events::Participants.page(
              event,
              page: query_integer(:page, default: Api::QueryParameters::DEFAULT_PAGE, minimum: 1),
              page_size: query_integer(:pageSize, default: Api::QueryParameters::DEFAULT_PAGE_SIZE, minimum: 1,
                                                   maximum: Api::QueryParameters::MAX_PAGE_SIZE),
              search: params[:q]
            )
            render_collection(records, blueprint: Api::ParticipantTicketBlueprint, pagination: pagination)
          end
        end
      end
    end
  end
end
