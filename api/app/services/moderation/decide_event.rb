# frozen_string_literal: true

module Moderation
  # Publishes or rejects an event that was submitted for moderation (US-6.2, FR-MOD-1..3).
  # `Under Review -> Published | Rejected` is allowed for moderators only (Technical Requirements, 4.3).
  class DecideEvent < Action
    DECISIONS = %w[approved rejected].freeze

    def initialize(event:, moderator:, decision:, reason: nil)
      super()
      @event = event
      @moderator = moderator
      @decision = decision.to_s
      @reason = normalize_reason(reason)
    end

    private

    attr_reader :event, :moderator, :decision, :reason

    def perform
      raise ArgumentError, "Unknown decision: #{decision}" unless DECISIONS.include?(decision)

      require_reason!(reason) if decision == 'rejected'
      event.lock!
      invalid_transition!(event) unless event.under_review?
      ensure_organization_can_publish! if decision == 'approved'

      event.update!(decision == 'approved' ? publish_attributes : reject_attributes)
      # US-5.3: every status change is recorded in event_status_histories.
      Events::Transition.record!(event: event, from: 'under_review', to: event.status, actor: moderator, reason: reason)
      ModerationLog.record!(entity: event, moderator: moderator, decision: decision, reason: reason)

      notify(:event_decision, event, decision, reason)
      track(action: "moderation.event.#{decision}", actor: moderator, entity: event, metadata: { reason: reason })
      event
    end

    # FR-ORG-2, FR-MOD-5: an organization that is not approved (pending, rejected, blocked) cannot publish.
    # The organization row stays locked until the approval commits, so a concurrent block cannot slip in
    # between this check and the update (lock order: event, then organization).
    def ensure_organization_can_publish!
      event.organization.lock!
      return if event.organization.accepts_event_changes?

      fail!(Api::ErrorCodes::INVALID_STATUS_TRANSITION, 'organization_not_approved',
        details: [ { field: 'organization', message: event.organization.status } ])
    end

    def publish_attributes
      { status: 'published', published_at: Time.current, reviewed_by: moderator, rejection_reason: nil }
    end

    def reject_attributes
      { status: 'rejected', reviewed_by: moderator, rejection_reason: reason }
    end
  end
end
