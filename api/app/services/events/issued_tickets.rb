# frozen_string_literal: true

module Events
  # How many tickets have been issued for an event.
  # A pending reservation is not issued. The count stays at zero until the tickets table exists.
  class IssuedTickets
    def self.for(event)
      event.ticket_types.sum { |ticket_type| TicketDemand.issued(ticket_type.id) }
    end
  end
end
