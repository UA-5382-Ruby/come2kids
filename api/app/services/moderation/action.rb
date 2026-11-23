# frozen_string_literal: true

module Moderation
  # Base class for moderation commands (EPIC-6). Returns Dry::Monads::Result, like Mails::Deliver:
  # Success(record) when the decision is saved, Failure(error) otherwise. A business-rule violation is
  # Failure(Api::ApplicationError); callers do `raise result.failure` and ErrorHandling renders it.
  #
  # Subclasses implement #perform, which runs inside a database transaction and may register side
  # effects (emails, activity log entries) with #after_commit. Side effects run only after the
  # transaction commits, so nobody is notified about a change that was rolled back.
  class Action
    include Dry::Monads[:result]

    REASON_MAX_LENGTH = 2000

    def self.call(**)
      new(**).call
    end

    def call
      ensure_reason_is_text!
      record = ApplicationRecord.transaction { perform }
      run_side_effects
      Success(record)
    rescue StandardError => e
      Failure(e)
    end

    # Runs this action inside the transaction of another action, which collects the side effects
    # and wraps the outcome in a Result. Errors propagate, so the outer transaction rolls back.
    def call_within(parent)
      record = perform
      parent.side_effects.concat(side_effects)
      record
    end

    protected

    def side_effects
      @side_effects ||= []
    end

    private

    def perform
      raise NotImplementedError
    end

    def after_commit(&block)
      side_effects << block
    end

    # The decision is already committed, so a failed notification (e.g. the queue is down) does not turn
    # the outcome into a Failure. It is reported to the error tracker (Rails.error) with the action name,
    # so operators can resend the lost email or activity log entry.
    def run_side_effects
      side_effects.each do |side_effect|
        side_effect.call
      rescue StandardError => e
        Rails.logger.error("[#{self.class.name}] side effect failed: #{e.class}: #{e.message}")
        Rails.error.report(e, handled: true, severity: :error, context: { action: self.class.name })
      end
    end

    # Keeps a string reason (stripped, blank → nil). Any other JSON type, e.g. `false` or a number, is
    # remembered and rejected by #ensure_reason_is_text! instead of being stored as "false".
    def normalize_reason(reason)
      return if reason.nil?
      return reason.strip.presence if reason.is_a?(String)

      @reason_not_text = true
      nil
    end

    def ensure_reason_is_text!
      validation_failed!(:reason, I18n.t('moderation.errors.reason_not_text')) if @reason_not_text
    end

    def require_reason!(reason)
      if reason.blank?
        validation_failed!(:reason, I18n.t('moderation.errors.reason_required'))
      elsif reason.length > REASON_MAX_LENGTH
        validation_failed!(:reason, I18n.t('moderation.errors.reason_too_long', count: REASON_MAX_LENGTH))
      end
    end

    def validation_failed!(field, message)
      raise Api::ApplicationError.new(code: Api::ErrorCodes::VALIDATION_FAILED,
        message: I18n.t('moderation.errors.validation_failed'), details: [ { field: field.to_s, message: message } ])
    end

    def fail!(code, key, details: [], **interpolations)
      raise Api::ApplicationError.new(code: code, message: I18n.t("moderation.errors.#{key}", **interpolations),
        details: details)
    end

    def invalid_transition!(record, current_status = record.status)
      fail!(Api::ErrorCodes::INVALID_STATUS_TRANSITION, 'invalid_transition',
        details: [ { field: 'status', message: current_status.to_s } ], status: current_status)
    end

    def notify(mailer_method, *args)
      after_commit { ModerationMailer.public_send(mailer_method, *args).deliver_later }
    end

    def track(action:, actor:, entity:, metadata: {})
      after_commit do
        ActivityLogJob.perform_later(
          'timestamp' => Time.current.utc, 'user_id' => actor&.id, 'role' => role_of(actor), 'action' => action,
          'entity_type' => entity.class.name, 'entity_id' => entity.id.to_s, 'result' => 'success',
          'ip' => Current.ip, 'user_agent' => Current.user_agent, 'request_id' => Current.request_id,
          'metadata' => metadata.deep_stringify_keys
        )
      end
    end

    def role_of(actor)
      return 'guest' if actor.nil?

      actor.moderator? ? 'moderator' : 'user'
    end
  end
end
