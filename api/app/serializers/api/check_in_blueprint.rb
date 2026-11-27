# frozen_string_literal: true

module Api
  class CheckInBlueprint < Blueprinter::Base
    identifier :id

    field :code
    field :status
    field :used_at

    field :holder_name do |ticket|
      "#{ticket.user.first_name} #{ticket.user.last_name}"
    end

    field :ticket_type_name do |ticket|
      ticket.ticket_type&.name
    end
  end
end
