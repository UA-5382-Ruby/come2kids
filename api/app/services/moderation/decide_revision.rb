# frozen_string_literal: true

module Moderation
  # Applies or rejects a pending edit of a published event (US-6.2, FR-MOD-6).
  # Approval replaces the public event through Events::Revisions::Apply, which also clears reminders when the
  # start time moves and, after the commit, tells subscribers and ticket holders about public changes.
  # Rejection requires a reason; the editor is emailed either way.
  class DecideRevision < Action
    DECISIONS = %w[approved rejected].freeze

    def initialize(revision:, moderator:, decision:, reason: nil)
      super()
      @revision = revision
      @moderator = moderator
      @decision = decision.to_s
      @reason = normalize_reason(reason)
    end

    private

    attr_reader :revision, :moderator, :decision, :reason

    def perform
      raise ArgumentError, "Unknown decision: #{decision}" unless DECISIONS.include?(decision)

      require_reason!(reason) if decision == 'rejected'
      revision.lock!
      invalid_transition!(revision) unless revision.pending?
      decision == 'approved' ? approve : reject
      ModerationLog.record!(entity: revision, moderator: moderator, decision: decision, reason: reason)

      notify(:revision_decision, revision, decision, reason)
      track(action: "moderation.event_revision.#{decision}", actor: moderator, entity: revision,
            metadata: { event_id: revision.event_id, reason: reason })
      revision
    end

    # Lock order: revision, event, organization. A cancelled event is not brought back by an old edit, and
    # an organization that is not approved (e.g. blocked meanwhile) cannot change its public events.
    def approve
      event = revision.event
      event.lock!
      invalid_transition!(event) unless event.published?
      ensure_organization_accepts_changes!(event)

      result = Events::Revisions::Apply.call(revision: revision, reviewer: moderator)
      # Apply joins this transaction; raising rolls back whatever it wrote before failing.
      raise ActiveRecord::RecordInvalid, result.failure if result.failure?
    end

    def reject
      revision.update!(status: 'rejected', reviewed_by: moderator, reviewed_at: Time.current,
                       rejection_reason: reason)
    end

    def ensure_organization_accepts_changes!(event)
      event.organization.lock!
      return if event.organization.accepts_event_changes?

      fail!(Api::ErrorCodes::INVALID_STATUS_TRANSITION, 'organization_not_approved',
        details: [ { field: 'organization', message: event.organization.status } ])
    end
  end
end
