# frozen_string_literal: true

module Api
  class ParticipantTicketBlueprint < Blueprinter::Base
    identifier :id

    fields :holder_name, :ticket_type_name, :check_in_state
  end
end
