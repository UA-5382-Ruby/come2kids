# frozen_string_literal: true

module Tickets
  class CheckInStatistics
    include Dry::Monads[:result]

    Summary = Struct.new(:issued, :checked_in, :remaining, :cancelled, :attendance_rate,
                         :by_ticket_type, keyword_init: true)

    def self.call(event:)
      new(event: event).call
    end

    def initialize(event:)
      @event = event
    end

    def call
      Success(summary(Ticket.where(event_id: @event.id).group(:status).count))
    end

    private

    def summary(counts)
      issued = counts.values.sum
      checked_in = counts.fetch('used', 0)
      Summary.new(issued: issued, checked_in: checked_in, remaining: counts.fetch('valid', 0),
                  cancelled: counts.fetch('cancelled', 0), attendance_rate: rate(checked_in, issued),
                  by_ticket_type: by_ticket_type)
    end

    def rate(checked_in, issued)
      return 0.0 if issued.zero?

      (checked_in * 100.0 / issued).round(2)
    end

    def by_ticket_type
      rows = Ticket.where(event_id: @event.id).joins(:ticket_type)
                   .group('ticket_types.id', 'ticket_types.name', 'tickets.status').count

      rows.each_with_object({}) do |((type_id, name, status), count), acc|
        entry = acc[type_id] ||= { ticket_type_id: type_id, name: name, issued: 0, checked_in: 0 }
        entry[:issued] += count
        entry[:checked_in] += count if status == 'used'
      end.values
    end
  end
end
