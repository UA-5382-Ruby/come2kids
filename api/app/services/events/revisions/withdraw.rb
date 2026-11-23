# frozen_string_literal: true

module Events
  module Revisions
    # Withdraws the pending revision so another one can be opened. Returns Dry::Monads::Result.
    class Withdraw
      include Dry::Monads[:result]

      def self.call(event:)
        new(event:).call
      end

      def initialize(event:)
        @event = event
      end

      def call
        revision = @event.event_revisions.pending.first
        return Failure(:missing) unless revision

        revision.update!(status: 'withdrawn')
        Success(revision)
      end
    end
  end
end
