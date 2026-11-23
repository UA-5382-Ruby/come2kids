# frozen_string_literal: true

module Appeals
  # Submits an appeal against a block (US-6.5, FR-APP-1..4, FR-APP-7).
  #
  # The target is the blocked user themself, or the blocked organization the user owns
  # (AppealPolicy checks who may appeal). Business rules checked here:
  # - the target must be blocked;
  # - one open appeal per target (also guaranteed by a partial unique index);
  # - after a rejection, a new appeal is accepted only after Appeal::RESUBMIT_COOLDOWN.
  class Submit < Moderation::Action
    def initialize(user:, target:, message:)
      super()
      @user = user
      @target = target
      @message = message.to_s.strip
    end

    private

    attr_reader :user, :target, :message

    def perform
      validate_message!
      target.lock!
      fail!(Api::ErrorCodes::NOT_BLOCKED, 'not_blocked') unless target.blocked?
      ensure_no_open_appeal!
      ensure_cooldown_passed!

      appeal = Appeal.create!(target: target, submitted_by: user, message: message)
      ModerationLog.record!(entity: appeal, decision: :appeal_submitted)
      track(action: 'appeal.submitted', actor: user, entity: appeal,
            metadata: { target_type: target.class.name, target_id: target.id })
      appeal
    rescue ActiveRecord::RecordNotUnique
      already_open!
    end

    def validate_message!
      if message.blank?
        validation_failed!(:message, I18n.t('moderation.errors.message_required'))
      elsif message.length > Appeal::MESSAGE_MAX_LENGTH
        validation_failed!(:message, I18n.t('moderation.errors.message_too_long', count: Appeal::MESSAGE_MAX_LENGTH))
      end
    end

    def ensure_no_open_appeal!
      already_open! if Appeal.for_target(target).currently_open.exists?
    end

    def already_open!
      fail!(Api::ErrorCodes::APPEAL_ALREADY_OPEN, 'appeal_already_open')
    end

    def ensure_cooldown_passed!
      allowed_at = Appeal.next_allowed_at(target)
      return if allowed_at.nil?

      iso_time = allowed_at.utc.iso8601
      fail!(Api::ErrorCodes::APPEAL_COOLDOWN, 'appeal_cooldown', time: iso_time,
        details: [ { field: 'next_appeal_allowed_at', message: iso_time } ])
    end
  end
end
