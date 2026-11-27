# frozen_string_literal: true

module Events
  # Queues the "event tomorrow" email (US-12.3, FR-REM-1..4). Runs from Events::SendRemindersJob at
  # least hourly.
  #
  # - Only publicly visible events starting within the next 24 hours: no cancelled, deleted or
  #   unpublished events and none of a blocked organization. An event approved less than 24 hours
  #   before its start is picked up on the next run.
  # - Recipients are event subscribers and holders of valid tickets, once each. Organization
  #   subscribers are not reminded.
  # - event_reminders (unique event_id + user_id) records who has been reminded, so later runs skip
  #   them. Events::ClearReminders empties it when the start time changes.
  class SendReminders
    WINDOW = 24.hours

    def self.call(now: Time.current)
      new(now).call
    end

    def initialize(now)
      @now = now
    end

    # Returns the number of reminders queued in this run.
    def call
      Event.publicly_visible.where(start_at: @now..(@now + WINDOW)).find_each.sum { |event| remind(event) }
    end

    private

    def remind(event)
      pending = Subscriptions::Audience.event(event)
                                       .where.not(id: EventReminder.where(event_id: event.id).select(:user_id))
      count = 0
      pending.select(:id).find_in_batches(batch_size: Subscriptions::Enqueue::BATCH_SIZE) do |users|
        count += remind_batch(event, users.map(&:id))
      end
      count
    end

    # The reminder rows and the outbox rows are written together: a crash in between leaves neither,
    # so the next run tries again. Only users whose reminder row was new in this run get an email.
    def remind_batch(event, user_ids)
      ApplicationRecord.transaction do
        rows = user_ids.map { |user_id| { event_id: event.id, user_id: user_id, sent_at: @now } }
        inserted = EventReminder.insert_all(rows, unique_by: %i[event_id user_id], returning: %i[user_id])
                                .rows.flatten
        next 0 if inserted.empty?

        enqueue(event, inserted)
        inserted.size
      end
    end

    # The start time is part of the key, so a reminder for a new date is not blocked by an outbox row
    # left from the old one.
    def enqueue(event, user_ids)
      start_at = event.start_at.utc.iso8601
      Subscriptions::Enqueue.call(
        template: Subscriptions::Notifier::EVENT_REMINDER,
        recipients: User.where(id: user_ids),
        key: "#{Subscriptions::Notifier::EVENT_REMINDER}:#{event.id}:#{event.start_at.to_i}",
        payload: { 'event_id' => event.id, 'start_at' => start_at }
      ) { |ids| Subscriptions::Notifier.subscription_ids(event, ids) }
    end
  end
end
