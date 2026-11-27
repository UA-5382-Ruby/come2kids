# frozen_string_literal: true

module Emails
  class ProcessOutboxJob < ApplicationJob
    queue_as :mailers

    DISPATCH = {
      Emails::EnqueuePurchase::TEMPLATE => ->(row) { TicketMailer.purchase_confirmation(row) },
      Subscriptions::Notifier::NEW_EVENT => ->(row) { SubscriptionMailer.new_event(row) },
      Subscriptions::Notifier::ORGANIZATION_UPDATED => ->(row) { SubscriptionMailer.organization_updated(row) },
      Subscriptions::Notifier::EVENT_CHANGED => ->(row) { SubscriptionMailer.event_changed(row) },
      Subscriptions::Notifier::EVENT_CANCELLED => ->(row) { SubscriptionMailer.event_cancelled(row) },
      Subscriptions::Notifier::EVENT_REMINDER => ->(row) { SubscriptionMailer.event_reminder(row) }
    }.freeze

    def perform
      enqueue_missing_purchases
      EmailOutbox.due.find_each { |row| deliver(row) }
    end

    private

    def enqueue_missing_purchases
      Order.where(status: 'paid').joins(:tickets).distinct.find_each do |order|
        Emails::EnqueuePurchase.call(order)
      end
    end

    def deliver(row)
      DISPATCH.fetch(row.template).call(row).deliver_now
      row.update!(status: 'sent', sent_at: Time.current, attempts: row.attempts + 1, last_error: nil)
    rescue StandardError => e
      row.update!(status: 'failed', attempts: row.attempts + 1, last_error: "#{e.class}: #{e.message}")
      Rails.logger.error("[Emails::ProcessOutboxJob] outbox #{row.id} failed: #{e.class}: #{e.message}")
    end
  end
end
