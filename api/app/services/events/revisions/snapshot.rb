# frozen_string_literal: true

module Events
  module Revisions
    # The editable data of an event in the shape of EventRevision#payload. Upsert starts a new revision from
    # it, and the moderation queue compares it with a pending revision to show old and new values (FR-MOD-6).
    # Associations are read in Ruby, so a queue that preloads them does not run a query per revision.
    module Snapshot
      module_function

      def take(event)
        {
          'category_id' => event.category_id,
          'start_at' => stamp(event.start_at),
          'end_at' => stamp(event.end_at),
          'time_zone' => event.time_zone,
          'location_type' => event.location_type,
          'address' => event.address,
          'city' => event.city,
          'online_url' => event.online_url,
          'translations' => event.event_translations.map { |row| translation(row) },
          'ticket_types' => event.ticket_types.sort_by(&:id).map { |row| ticket_type(row) },
          'images' => event.event_media.sort_by { |row| [ row.position, row.id ] }.map { |row| image(row, row.position) }
        }
      end

      def translation(row)
        { 'locale' => row.locale, 'title' => row.title, 'description' => row.description }
      end

      def ticket_type(row)
        {
          'id' => row.id, 'name' => row.name, 'price' => row.price, 'total_quantity' => row.total_quantity,
          'sale_start_at' => stamp(row.sale_start_at), 'sale_end_at' => stamp(row.sale_end_at)
        }
      end

      def image(media, position)
        {
          'id' => media.id, 'blob_id' => (media.file.blob.id if media.file.attached?),
          'kind' => media.kind, 'position' => position.to_i
        }
      end

      def stamp(time)
        time&.utc&.iso8601(3)
      end
    end
  end
end
