# frozen_string_literal: true

module Jobs
  # Placeholder recurring work for sidekiq-cron. Returns Dry::Monads::Result.
  class ExampleHeartbeat
    include Dry::Monads[:result]

    def self.call
      new.call
    end

    def call
      Rails.logger.info("[Jobs::ExampleHeartbeat] scheduler heartbeat at #{Time.current.utc.iso8601}")
      Success({ timestamp: Time.current.utc.iso8601 })
    rescue StandardError => e
      Failure(e)
    end
  end
end
