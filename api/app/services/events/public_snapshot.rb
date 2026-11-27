# frozen_string_literal: true

module Events
  # The public event data that subscribers and ticket holders are told about when it changes
  # (FR-SUB-3, FR-EM-3): date and time, location and ticket prices.
  #
  #   before = PublicSnapshot.take(event)
  #   ... apply the revision ...
  #   PublicSnapshot.diff(before, PublicSnapshot.take(event))
  #   # => { 'schedule' => { 'from' => {...}, 'to' => {...} }, 'prices' => {...} }
  #
  # Values are plain JSON so the diff can travel in a job argument and an outbox payload.
  class PublicSnapshot
    def self.take(event)
      {
        'schedule' => {
          'start_at' => event.start_at&.utc&.iso8601,
          'end_at' => event.end_at&.utc&.iso8601,
          'time_zone' => event.time_zone
        },
        'location' => {
          'location_type' => event.location_type,
          'address' => event.address,
          'city' => event.city,
          'online_url' => event.online_url
        },
        # Read from the database, so ticket types written during the revision are included.
        'prices' => TicketType.where(event_id: event.id).order(:id).pluck(:name, :price).to_h
      }
    end

    # Only the groups that changed, each with its old ("from") and new ("to") values.
    def self.diff(before, after)
      after.each_with_object({}) do |(group, values), changes|
        changes[group] = { 'from' => before[group], 'to' => values } if before[group] != values
      end
    end
  end
end
