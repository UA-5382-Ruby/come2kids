# frozen_string_literal: true

module ActivityLogs
  # Writes append-only activity log documents to MongoDB.
  # Always returns Dry::Monads::Result — never raises to the caller.
  class Writer
    include Dry::Monads[:result]

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(**attrs)
      @attrs = attrs
    end

    def call
      log = ActivityLog.create!(
        timestamp: @attrs[:timestamp] || Time.current.utc,
        user_id: @attrs[:user_id],
        role: @attrs[:role],
        action: @attrs.fetch(:action),
        entity_type: @attrs[:entity_type],
        entity_id: @attrs[:entity_id]&.to_s,
        result: @attrs.fetch(:result, 'failure'),
        ip: @attrs[:ip],
        user_agent: @attrs[:user_agent],
        request_id: @attrs[:request_id],
        metadata: @attrs.fetch(:metadata, {}),
      )
      Success(log)
    rescue StandardError => e
      Rails.logger.error("[ActivityLogs::Writer] failed to persist log: #{e.class}: #{e.message}")
      Failure(e)
    end
  end
end
