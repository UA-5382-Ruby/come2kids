# frozen_string_literal: true

module Api
  module V1
    class TicketsController < ApplicationController
      before_action :authenticate_user!

      CONTENT_TYPES = { 'png' => 'image/png', 'svg' => 'image/svg+xml' }.freeze

      def my
        authorize Ticket
        tickets, pagination = paginate_collection(
          Ticket.where(user: current_user).includes(:ticket_type),
          sortable: { issued_at: :issued_at, created_at: :created_at, status: :status },
          filterable: { status: :status, event_id: :event_id },
          default_sort: :issued_at
        )

        render_collection tickets, blueprint: Api::TicketBlueprint, pagination: pagination
      end

      def show
        ticket = Ticket.includes(:ticket_type).find(params[:id])
        authorize ticket

        render_resource ticket, blueprint: Api::TicketBlueprint
      end

      def qr
        ticket = Ticket.find(params[:id])
        authorize ticket, :qr?

        format = params[:format].presence || 'png'
        result = Tickets::RenderQr.call(ticket, format: format)
        raise Api::ApplicationError.new(code: Api::ErrorCodes::BAD_REQUEST, message: 'Unsupported QR format.') if result.failure?

        response.set_header('Cache-Control', 'private, no-store')
        send_data result.value!, type: CONTENT_TYPES.fetch(format), disposition: 'inline',
                  filename: "ticket-#{ticket.code}.#{format}"
      end

      def pdf
        ticket = Ticket.includes(:user, :ticket_type, event: :event_translations).find(params[:id])
        authorize ticket, :pdf?

        result = Tickets::RenderPdf.call(ticket)
        raise result.failure if result.failure?

        log_download(ticket)
        response.set_header('Cache-Control', 'private, no-store')
        send_data result.value!, type: 'application/pdf', disposition: 'attachment',
                  filename: "ticket-#{ticket.code}.pdf"
      end

      private

      def log_download(ticket)
        ActivityLogJob.perform_later(
          'timestamp' => Time.current.utc, 'user_id' => current_user.id, 'role' => ticket_role,
          'action' => 'ticket.download', 'entity_type' => 'Ticket', 'entity_id' => ticket.id.to_s,
          'result' => 'success', 'ip' => Current.ip, 'user_agent' => Current.user_agent,
          'request_id' => Current.request_id, 'metadata' => {}
        )
      end

      def ticket_role
        current_user.moderator? ? 'moderator' : 'user'
      end
    end
  end
end
