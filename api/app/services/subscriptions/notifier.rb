# frozen_string_literal: true

module Subscriptions
  # Queues subscription emails for one public change (US-12.2, FR-SUB-2..4). Runs inside
  # Subscriptions::NotifyJob, so a large audience never slows down the request that made the change.
  # The payload keeps ids only: SubscriptionMailer renders the email in the recipient's language at
  # delivery time and checks again that the recipient may still receive it.
  class Notifier
    NEW_EVENT = 'subscription_new_event'
    ORGANIZATION_UPDATED = 'subscription_organization_updated'
    EVENT_CHANGED = 'subscription_event_changed'
    EVENT_CANCELLED = 'subscription_event_cancelled'
    EVENT_REMINDER = 'event_reminder'

    class << self
      # An organization published a new event (after moderation approval).
      def new_event(event)
        return unless Event.publicly_visible.exists?(id: event.id)

        organization = event.organization
        Enqueue.call(template: NEW_EVENT, recipients: Audience.organization(organization),
                     key: "#{NEW_EVENT}:#{event.id}", payload: { 'event_id' => event.id }) do |ids|
          subscription_ids(organization, ids)
        end
      end

      # The public information of an organization changed. `version` identifies this change, so two
      # different edits are both sent while a retry of the same edit is not.
      def organization_updated(organization, version:)
        return unless Organization.publicly_visible.exists?(id: organization.id)

        Enqueue.call(template: ORGANIZATION_UPDATED, recipients: Audience.organization(organization),
                     key: "#{ORGANIZATION_UPDATED}:#{organization.id}:#{version}",
                     payload: { 'organization_id' => organization.id }) do |ids|
          subscription_ids(organization, ids)
        end
      end

      # An approved revision changed the date, time, location or price (see Events::PublicSnapshot).
      def event_changed(event, revision_id:, changes:)
        return if changes.blank? || !Event.publicly_visible.exists?(id: event.id)

        Enqueue.call(template: EVENT_CHANGED, recipients: Audience.event(event),
                     key: "#{EVENT_CHANGED}:#{revision_id}",
                     payload: { 'event_id' => event.id, 'changes' => changes }) do |ids|
          subscription_ids(event, ids)
        end
      end

      def event_cancelled(event)
        return if event.cancelled_at.nil?

        Enqueue.call(template: EVENT_CANCELLED, recipients: Audience.event(event),
                     key: "#{EVENT_CANCELLED}:#{event.id}", payload: { 'event_id' => event.id }) do |ids|
          subscription_ids(event, ids)
        end
      end

      # { user_id => { 'subscription_id' => id } } for the users of one batch who follow the target.
      def subscription_ids(target, user_ids)
        Subscription.for_target(target).where(user_id: user_ids).pluck(:user_id, :id)
                    .to_h { |user_id, id| [ user_id, { 'subscription_id' => id } ] }
      end
    end
  end
end
