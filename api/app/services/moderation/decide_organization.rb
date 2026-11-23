# frozen_string_literal: true

module Moderation
  # Approves or rejects an organization waiting for approval (US-6.1, FR-ORG-2, FR-MOD-1..3).
  class DecideOrganization < Action
    DECISIONS = %w[approved rejected].freeze

    def initialize(organization:, moderator:, decision:, reason: nil)
      super()
      @organization = organization
      @moderator = moderator
      @decision = decision.to_s
      @reason = normalize_reason(reason)
    end

    private

    attr_reader :organization, :moderator, :decision, :reason

    def perform
      raise ArgumentError, "Unknown decision: #{decision}" unless DECISIONS.include?(decision)

      require_reason!(reason) if decision == 'rejected'
      organization.lock!
      invalid_transition!(organization) unless organization.pending_approval?

      organization.update!(decision == 'approved' ? approve_attributes : reject_attributes)
      ModerationLog.record!(entity: organization, moderator: moderator, decision: decision, reason: reason)

      notify(:organization_decision, organization, decision, reason) if organization.owner
      track(action: "moderation.organization.#{decision}", actor: moderator, entity: organization,
            metadata: { reason: reason })
      organization
    end

    def approve_attributes
      { status: 'approved', approved_at: Time.current, approved_by: moderator, rejection_reason: nil }
    end

    def reject_attributes
      { status: 'rejected', rejection_reason: reason }
    end
  end
end
