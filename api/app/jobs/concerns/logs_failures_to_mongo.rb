# frozen_string_literal: true

# Opt-in for US-1.4 jobs only — retries exhausted failures into Mongo via Dry::Monads::Result.
module LogsFailuresToMongo
  extend ActiveSupport::Concern

  included do
    retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
      log_result = ActivityLogs::Writer.call(
        action: job.try(:failure_log_action) || 'job.failed',
        result: 'failure',
        entity_type: job.class.name,
        entity_id: job.job_id,
        metadata: {
          job_class: job.class.name,
          job_id: job.job_id,
          queue_name: job.queue_name,
          arguments: job.arguments.inspect,
          error_class: error.class.name,
          error_message: error.message
        },
      )
      if log_result.failure?
        Rails.logger.error("[#{job.class.name}] Mongo log write failed: #{log_result.failure}")
      end
    end

    discard_on ActiveJob::DeserializationError do |job, error|
      log_result = ActivityLogs::Writer.call(
        action: 'job.discarded',
        result: 'failure',
        entity_type: job.class.name,
        entity_id: job.job_id,
        metadata: {
          job_class: job.class.name,
          job_id: job.job_id,
          error_class: error.class.name,
          error_message: error.message
        },
      )
      if log_result.failure?
        Rails.logger.error("[#{job.class.name}] Mongo log write failed: #{log_result.failure}")
      end
    end
  end
end
