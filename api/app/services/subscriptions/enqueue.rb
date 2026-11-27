# frozen_string_literal: true

module Subscriptions
  # Writes one email_outboxes row per recipient (T-12.2.2). Recipients are read and inserted in batches,
  # so a large audience is never loaded into memory at once. The unique dedup_key makes the write
  # idempotent: a retried job or a repeated trigger for the same change does not send a second email.
  # Emails::ProcessOutboxJob delivers the rows and retries failures.
  class Enqueue
    BATCH_SIZE = 500

    # The optional block gets the user ids of one batch and returns { user_id => extra payload }.
    def self.call(template:, recipients:, key:, payload: {}, &extras)
      recipients.select(:id, :email).find_in_batches(batch_size: BATCH_SIZE) do |users|
        per_user = extras ? extras.call(users.map(&:id)) : {}
        rows = users.map { |user| row(template, key, user, payload.merge(per_user.fetch(user.id, {}))) }
        EmailOutbox.insert_all(rows, unique_by: :dedup_key)
      end
    end

    def self.row(template, key, user, payload)
      {
        to_email: user.email,
        template: template,
        dedup_key: "#{key}:#{user.id}",
        payload: payload.merge('user_id' => user.id),
        status: 'pending',
        attempts: 0
      }
    end

    private_class_method :row
  end
end
