# frozen_string_literal: true

module Events
  # Notifies ticket holders and event subscribers after an organizer cancels a published event
  # (FR-EM-4, FR-SUB-3). Emails are queued in the outbox and delivered by Emails::ProcessOutboxJob.
  class CancellationNoticeJob < ApplicationJob
    queue_as :mailers

    def perform(event_id)
      event = Event.find_by(id: event_id)
      Subscriptions::Notifier.event_cancelled(event) if event
    end
  end
end
