# frozen_string_literal: true

module Events
  # One notice after an organizer cancels an event that already has tickets.
  # Collects recipient ids and does not render or send the email.
  class CancellationNoticeJob < ApplicationJob
    queue_as :default

    def perform(event_id)
      event = Event.find_by(id: event_id)
      return [] unless event

      CancellationNotice.recipient_ids(event)
    end
  end
end
