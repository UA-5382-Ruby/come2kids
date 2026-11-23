# frozen_string_literal: true

module Appeals
  # A moderator accepts or rejects an open appeal (US-6.5, FR-APP-5..7).
  # Accepting unblocks the user, or returns the organization to `approved`; rejecting needs a reason.
  # The appellant gets one email with the decision.
  class Decide < Moderation::Action
    DECISIONS = %w[accepted rejected].freeze

    def initialize(appeal:, moderator:, decision:, reason: nil)
      super()
      @appeal = appeal
      @moderator = moderator
      @decision = decision.to_s
      @reason = normalize_reason(reason)
    end

    private

    attr_reader :appeal, :moderator, :decision, :reason

    def perform
      raise ArgumentError, "Unknown decision: #{decision}" unless DECISIONS.include?(decision)

      require_reason!(reason) if decision == 'rejected'
      # Same lock order as a direct unblock (target, then appeal), so the two cannot deadlock.
      appeal.target.lock!
      appeal.lock!
      invalid_transition!(appeal) unless appeal.open?

      appeal.update!(status: decision, reviewed_by: moderator, reviewed_at: Time.current, decision_reason: reason)
      ModerationLog.record!(entity: appeal, moderator: moderator, decision: "appeal_#{decision}", reason: reason)
      unblock_target if decision == 'accepted' && appeal.target.blocked?

      notify(:appeal_decision, appeal)
      track(action: "moderation.appeal.#{decision}", actor: moderator, entity: appeal,
            metadata: { reason: reason, target_type: appeal.target_type, target_id: appeal.target_id })
      appeal
    end

    def unblock_target
      service = if appeal.target.is_a?(User)
        Moderation::UnblockUser.new(user: appeal.target, moderator: moderator, reason: reason, notify: false)
      else
        Moderation::UnblockOrganization.new(organization: appeal.target, moderator: moderator, reason: reason,
                                            notify: false)
      end
      service.call_within(self)
    end
  end
end
