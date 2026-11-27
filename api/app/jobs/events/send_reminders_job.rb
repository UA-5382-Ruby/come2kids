# frozen_string_literal: true

module Events
  # Hourly (config/sidekiq_schedule.yml): queues reminders for events starting within 24 hours (US-12.3).
  class SendRemindersJob < ApplicationJob
    queue_as :default

    def perform
      SendReminders.call
    end
  end
end
