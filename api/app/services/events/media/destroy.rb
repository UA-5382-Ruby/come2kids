# frozen_string_literal: true

module Events
  module Media
    # Removes a banner or gallery image. Returns Dry::Monads::Result.
    class Destroy
      include Dry::Monads[:result]

      def self.call(media:)
        new(media:).call
      end

      def initialize(media:)
        @media = media
      end

      def call
        @media.destroy!
        Success(@media)
      rescue ActiveRecord::RecordNotDestroyed => e
        Failure(e.record)
      end
    end
  end
end
