# frozen_string_literal: true

module Api
  class TicketBlueprint < Blueprinter::Base
    identifier :id
    fields :event_id, :code, :qr_token, :status

    field :ticket_type_name do |ticket|
      ticket.ticket_type&.name
    end

    field :issued_at do |ticket|
      ticket.issued_at&.utc&.iso8601(3)
    end

    field :used_at do |ticket|
      ticket.used_at&.utc&.iso8601(3)
    end
  end
end
