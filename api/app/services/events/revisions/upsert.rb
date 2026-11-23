# frozen_string_literal: true

module Events
  module Revisions
    # Creates or updates the single pending revision of a published event.
    # Returns Dry::Monads::Result and does not change the public row.
    class Upsert
      include Dry::Monads[:result]

      SCALAR = %i[category_id start_at end_at time_zone location_type address city online_url].freeze

      def self.call(event:, actor:, attributes:)
        new(event:, actor:, attributes:).call
      end

      def initialize(event:, actor:, attributes:)
        @event = event
        @actor = actor
        @attributes = attributes.to_h.deep_symbolize_keys
        @revision = event.event_revisions.pending.first ||
                    event.event_revisions.build(submitted_by: actor, status: 'under_review')
      end

      def call
        payload = build_payload
        validate_snapshot(payload)
        return Failure(@revision) if @revision.errors.any?

        @revision.assign_attributes(payload: payload, submitted_by: @actor, status: 'under_review')
        @revision.save!
        Success(@revision)
      rescue ActiveRecord::RecordNotUnique
        @revision.errors.add(:event, 'already has a pending revision')
        Failure(@revision)
      end

      private

      def build_payload
        payload = current_snapshot
        SCALAR.each { |key| payload[key.to_s] = @attributes[key] if @attributes.key?(key) }
        payload['translations'] = translation_rows if @attributes.key?(:translations)
        payload['ticket_types'] = ticket_type_rows if @attributes.key?(:ticket_types)
        payload['images'] = image_rows if @attributes.key?(:images)
        payload
      end

      def current_snapshot
        {
          'category_id' => @event.category_id,
          'start_at' => stamp(@event.start_at),
          'end_at' => stamp(@event.end_at),
          'time_zone' => @event.time_zone,
          'location_type' => @event.location_type,
          'address' => @event.address,
          'city' => @event.city,
          'online_url' => @event.online_url,
          'translations' => @event.event_translations.map { |row| translation_hash(row) },
          'ticket_types' => @event.ticket_types.map { |row| ticket_type_hash(row) },
          'images' => @event.event_media.order(:position, :id).map { |row| image_hash(row, row.position) }
        }
      end

      def translation_rows
        Array(@attributes[:translations]).map do |raw|
          values = raw.to_h.symbolize_keys
          { 'locale' => values[:locale], 'title' => values[:title], 'description' => values[:description] }
        end
      end

      def ticket_type_rows
        Array(@attributes[:ticket_types]).map do |raw|
          values = raw.to_h.symbolize_keys
          row = {
            'name' => values[:name], 'price' => values[:price], 'total_quantity' => values[:total_quantity],
            'sale_start_at' => values[:sale_start_at], 'sale_end_at' => values[:sale_end_at]
          }
          row['id'] = values[:id].to_i if values[:id].present?
          row['price'] = values[:price].to_i
          row['total_quantity'] = values[:total_quantity].to_i
          row
        end
      end

      def image_rows
        Array(@attributes[:images]).map do |raw|
          values = raw.to_h.symbolize_keys
          media = @event.event_media.find_by(id: values[:id])
          next image_error(values[:id]) unless media
          next image_error(values[:id], 'kind does not match') if values[:kind].present? && values[:kind] != media.kind

          image_hash(media, values.fetch(:position, media.position))
        end
      end

      def validate_snapshot(payload)
        require_schedule(payload)
        require_place(payload)
        require_uk_title(payload['translations'])
        @revision.errors.add(:category, :blank) if payload['category_id'].blank?
        @revision.errors.add(:ticket_types, 'must include at least one') if Array(payload['ticket_types']).empty?
        validate_ticket_types(Array(payload['ticket_types']))
        @revision.errors.add(:images, 'contain an image that is not on this event') if payload['images']&.include?(nil)
      end

      def require_schedule(payload)
        @revision.errors.add(:start_at, :blank) if payload['start_at'].blank?
        @revision.errors.add(:end_at, :blank) if payload['end_at'].blank?
        @revision.errors.add(:time_zone, :blank) if payload['time_zone'].blank?
        return if payload['start_at'].blank? || payload['end_at'].blank?

        start_at = Time.zone.parse(payload['start_at'].to_s)
        finish = Time.zone.parse(payload['end_at'].to_s)
        @revision.errors.add(:end_at, 'must be after start_at') if start_at && finish && finish <= start_at
      end

      def require_place(payload)
        case payload['location_type']
        when 'offline'
          @revision.errors.add(:address, :blank) if payload['address'].blank?
        when 'online'
          @revision.errors.add(:online_url, :blank) if payload['online_url'].blank?
        else
          @revision.errors.add(:location_type, 'must be offline with an address or online with a link')
        end
      end

      def require_uk_title(rows)
        ready = Array(rows).any? { |row| row['locale'] == 'uk' && row['title'].present? }
        return if ready

        @revision.errors.add(:translations, 'uk title is required')
      end

      def validate_ticket_types(rows)
        ids = rows.filter_map { |row| row['id'] }
        @event.ticket_types.each do |existing|
          next if ids.include?(existing.id)

          demand = TicketDemand.for(existing.id)
          @revision.errors.add(:ticket_types, "cannot remove #{existing.name}") if demand.positive?
        end
        rows.each_with_index { |row, index| validate_ticket_type(row, index) }
      end

      def validate_ticket_type(row, index)
        if row['id'].present? && @event.ticket_types.none? { |type| type.id == row['id'] }
          @revision.errors.add("ticket_types[#{index}].id", 'is not a ticket type of this event')
        end
        @revision.errors.add("ticket_types[#{index}].name", :blank) if row['name'].blank?
        quantity = row['total_quantity'].to_i
        demand = row['id'].present? ? TicketDemand.for(row['id']) : 0
        return if quantity.positive? && quantity >= demand

        @revision.errors.add("ticket_types[#{index}].total_quantity", 'is below tickets already held')
      end

      def translation_hash(row)
        { 'locale' => row.locale, 'title' => row.title, 'description' => row.description }
      end

      def ticket_type_hash(row)
        {
          'id' => row.id, 'name' => row.name, 'price' => row.price, 'total_quantity' => row.total_quantity,
          'sale_start_at' => stamp(row.sale_start_at), 'sale_end_at' => stamp(row.sale_end_at)
        }
      end

      def image_hash(media, position)
        {
          'id' => media.id, 'blob_id' => (media.file.blob.id if media.file.attached?),
          'kind' => media.kind, 'position' => position.to_i
        }
      end

      def image_error(_id, _message = 'is not an image of this event')
        nil
      end

      def stamp(time)
        time&.utc&.iso8601(3)
      end
    end
  end
end
