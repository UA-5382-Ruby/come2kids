# frozen_string_literal: true

module Api
  module V1
    module Organizations
      module Events
        class CheckInsController < ApplicationController
          before_action :authenticate_user!

          def create
            event = Event.where(organization_id: params[:organization_id]).find(params[:event_id])
            authorize event, :check_in?

            result = Tickets::CheckIn.call(event: event, token: params[:qr_token], user: current_user)
            raise result.failure if result.failure?

            ticket = result.value!
            log_check_in(ticket)
            render_resource ticket, blueprint: Api::CheckInBlueprint
          end

          private

          def log_check_in(ticket)
            ActivityLogJob.perform_later(
              'timestamp' => Time.current.utc, 'user_id' => current_user.id, 'role' => scanner_role,
              'action' => 'ticket.check_in', 'entity_type' => 'Ticket', 'entity_id' => ticket.id.to_s,
              'result' => 'success', 'ip' => Current.ip, 'user_agent' => Current.user_agent,
              'request_id' => Current.request_id, 'metadata' => { 'event_id' => ticket.event_id }
            )
          end

          def scanner_role
            current_user.moderator? ? 'moderator' : 'user'
          end
        end
      end
    end
  end
end
