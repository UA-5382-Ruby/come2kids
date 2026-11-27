# frozen_string_literal: true

module Events
  module Revisions
    # Old and new values of a pending revision, side by side (FR-MOD-6):
    #
    #   Diff.call(revision)
    #   # => [{ 'field' => 'city', 'old' => 'Київ', 'new' => 'Львів' }, ...]
    #
    # Only the payload fields that differ from the public event are listed. Timestamps are compared as
    # instants, so "2026-12-01T10:00:00Z" and "2026-12-01T10:00:00.000Z" are the same value.
    module Diff
      TIME_KEYS = %w[start_at end_at sale_start_at sale_end_at].freeze

      module_function

      def call(revision)
        current = Snapshot.take(revision.event)
        proposed = revision.payload.to_h
        proposed.filter_map do |field, new_value|
          old_value = current[field]
          next if normalize(field, old_value) == normalize(field, new_value)

          { 'field' => field, 'old' => old_value, 'new' => new_value }
        end
      end

      def normalize(key, value)
        case value
        when Hash then value.to_h { |nested_key, nested| [ nested_key.to_s, normalize(nested_key.to_s, nested) ] }
        when Array then value.map { |item| normalize(key, item) }
        else TIME_KEYS.include?(key) ? time(value) : value
        end
      end

      def time(value)
        return if value.blank?

        Time.zone.parse(value.to_s)&.utc&.iso8601(3) || value
      rescue ArgumentError
        value
      end
    end
  end
end
