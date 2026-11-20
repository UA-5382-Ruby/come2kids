# frozen_string_literal: true

module Events
  # Hides an event with no issued tickets, or cancels a published event that has them.
  # Returns Dry::Monads::Result. Does not refund.
  class DeleteOrCancel
    include Dry::Monads[:result]

    def self.call(event:, actor:)
      new(event:, actor:).call
    end

    def initialize(event:, actor:)
      @event = event
      @actor = actor
    end

    def call
      return Failure(:deleted) if @event.deleted_at.present?
      return hide unless IssuedTickets.for(@event).positive?

      cancel
    end

    private

    def hide
      @event.update!(deleted_at: Time.current)
      Success(@event)
    end

    def cancel
      unless @event.published?
        @event.errors.add(:status, 'cannot be cancelled unless it is published')
        return Failure(@event)
      end

      result = Transition.call(event: @event, to: 'cancelled_by_organizer', actor: @actor)
      return result if result.failure?

      CancellationNoticeJob.perform_later(@event.id)
      Success(@event)
    end
  end
end
