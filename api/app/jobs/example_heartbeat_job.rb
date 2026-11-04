# frozen_string_literal: true

# Placeholder recurring job loaded by sidekiq-cron (see config/sidekiq_schedule.yml).
# Replace later with reminders, reservation expiry and payment checks.
class ExampleHeartbeatJob < ApplicationJob
  include LogsFailuresToMongo

  queue_as :low

  def perform
    result = Jobs::ExampleHeartbeat.call
    return if result.success?

    raise result.failure
  end
end
