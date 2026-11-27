# frozen_string_literal: true

module Events
  module Revisions
    # Replaces the public event with an approved revision. Returns Dry::Monads::Result.
    # Moderation::DecideRevision (POST /moderation/event-revisions/{id}/approve) calls this.
    class Apply
      include Dry::Monads[:result]

      def self.call(revision:, reviewer:)
        new(revision:, reviewer:).call
      end

      def initialize(revision:, reviewer:)
        @revision = revision
        @reviewer = reviewer
        @event = revision.event
        @payload = revision.payload
      end

      def call
        return deny('is not pending') unless @revision.pending?

        previous_start = @event.start_at
        Event.transaction do
          apply_event
          replace_translations
          replace_ticket_types
          sync_images
          @event.save!
          ClearReminders.call(@event) if start_changed?(previous_start)
          @revision.update!(status: 'approved', reviewed_by: @reviewer, reviewed_at: Time.current)
        end
        Success(@event)
      rescue ActiveRecord::RecordInvalid => e
        Failure(e.record)
      end

      private

      def apply_event
        @event.assign_attributes(
          category_id: @payload['category_id'],
          start_at: parse_time(@payload['start_at']),
          end_at: parse_time(@payload['end_at']),
          time_zone: @payload['time_zone'],
          location_type: @payload['location_type'],
          address: @payload['address'],
          city: @payload['city'],
          online_url: @payload['online_url'],
          status: 'published'
        )
      end

      def replace_translations
        @event.event_translations.destroy_all
        Array(@payload['translations']).each do |row|
          @event.event_translations.create!(
            locale: row['locale'], title: row['title'], description: row['description']
          )
        end
      end

      def replace_ticket_types
        kept = Array(@payload['ticket_types']).map { |row| write_ticket_type(row) }
        @event.ticket_types.where.not(id: kept).find_each { |type| remove_ticket_type(type) }
      end

      def write_ticket_type(row)
        type = row['id'].present? ? @event.ticket_types.find(row['id']) : @event.ticket_types.build
        type.update!(
          name: row['name'], price: row['price'], total_quantity: row['total_quantity'],
          sale_start_at: parse_time(row['sale_start_at']), sale_end_at: parse_time(row['sale_end_at']),
          currency: TicketType::CURRENCY, sold_quantity: type.sold_quantity || 0
        )
        type.id
      end

      def remove_ticket_type(type)
        return type.destroy! unless TicketDemand.for(type.id).positive?

        @event.errors.add(:ticket_types, "cannot remove #{type.name}")
        raise ActiveRecord::RecordInvalid, @event
      end

      def sync_images
        kept = Array(@payload['images']).map { |row| row['id'].to_i }
        @event.event_media.where.not(id: kept).find_each(&:destroy!)
        Array(@payload['images']).each do |row|
          @event.event_media.find(row['id']).update!(position: row['position'].to_i)
        end
      end

      def start_changed?(previous)
        previous&.utc&.iso8601 != @event.start_at&.utc&.iso8601
      end

      def parse_time(value)
        return if value.blank?

        Time.zone.parse(value.to_s)
      end

      def deny(message)
        @revision.errors.add(:status, message)
        Failure(@revision)
      end
    end
  end
end
