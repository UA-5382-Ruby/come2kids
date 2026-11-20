# frozen_string_literal: true

module Events
  module Media
    # Replaces the gallery order. Returns Dry::Monads::Result.
    class Reorder
      include Dry::Monads[:result]

      def self.call(event:, image_ids:)
        new(event:, image_ids:).call
      end

      def initialize(event:, image_ids:)
        @event = event
        @image_ids = Array(image_ids).map(&:to_i)
      end

      def call
        return Failure(invalid_order) unless same_images?

        EventMedia.transaction do
          @image_ids.each_with_index do |id, index|
            @event.event_media.gallery.find(id).update!(position: index)
          end
        end
        Success(@event.event_media.gallery.to_a)
      rescue ActiveRecord::RecordInvalid => e
        Failure(e.record)
      end

      private

      def same_images?
        current = @event.event_media.gallery.pluck(:id)
        @image_ids.uniq.length == @image_ids.length && @image_ids.sort == current.sort
      end

      def invalid_order
        media = EventMedia.new(event: @event, kind: 'gallery', position: 0)
        media.errors.add(:image_ids, 'must list every gallery image once')
        media
      end
    end
  end
end
