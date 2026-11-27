# frozen_string_literal: true

module Subscriptions
  # Fans a public change out to subscribers asynchronously (FR-SUB-4). Enqueue it only after the change
  # has been committed, so nobody is told about a change that was rolled back.
  class NotifyJob < ApplicationJob
    queue_as :mailers

    def perform(kind, record_id, options = {})
      case kind
      when 'new_event'
        with(Event, record_id) { |event| Notifier.new_event(event) }
      when 'organization_updated'
        with(Organization, record_id) { |org| Notifier.organization_updated(org, version: options.fetch('version')) }
      when 'event_changed'
        with(Event, record_id) do |event|
          Notifier.event_changed(event, revision_id: options.fetch('revision_id'), changes: options.fetch('changes'))
        end
      when 'event_cancelled'
        with(Event, record_id) { |event| Notifier.event_cancelled(event) }
      else
        raise ArgumentError, "Unknown subscription notification: #{kind}"
      end
    end

    private

    def with(model, id)
      record = model.find_by(id: id)
      yield record if record
    end
  end
end
