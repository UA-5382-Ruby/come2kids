# frozen_string_literal: true

# Writes an activity log document to MongoDB outside the request (FR-LOG-1), so a slow or
# unavailable MongoDB never delays an API response. ActivityLogs::Writer returns
# Dry::Monads::Result; a failure is logged, as in LogsFailuresToMongo (retrying a Mongo write
# into Mongo would not help).
class ActivityLogJob < ApplicationJob
  queue_as :default
  # The payload holds IP, user agent and moderation reasons; keep them out of routine job logs.
  self.log_arguments = false

  def perform(attributes)
    result = ActivityLogs::Writer.call(**attributes.symbolize_keys)
    return if result.success?

    Rails.logger.error("[ActivityLogJob] activity log write failed: #{result.failure}")
  end
end
