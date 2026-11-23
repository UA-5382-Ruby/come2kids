# frozen_string_literal: true

module Moderation
  # Unblocks an organization (US-6.4, FR-APP-6). An organization that had been approved returns to
  # `approved`, so its published events become visible and ticket sales resume. One that was blocked
  # before its approval returns to `pending_approval` and still needs a moderation decision.
  class UnblockOrganization < Action
    def initialize(organization:, moderator:, reason: nil, notify: true)
      super()
      @organization = organization
      @moderator = moderator
      @reason = normalize_reason(reason)
      @notify_owner = notify
    end

    private

    attr_reader :organization, :moderator, :reason

    def perform
      require_reason!(reason) if reason
      organization.lock!
      fail!(Api::ErrorCodes::NOT_BLOCKED, 'not_blocked') unless organization.blocked?

      organization.update!(status: organization.approved_at ? 'approved' : 'pending_approval',
                           blocked_at: nil, blocked_by: nil, block_reason: nil)
      ModerationLog.record!(entity: organization, moderator: moderator, decision: :unblocked, reason: reason)
      Appeal.close_open_for!(organization, moderator: moderator, reason: reason)

      notify(:organization_block_changed, organization, 'unblocked', reason) if @notify_owner && organization.owner
      track(action: 'moderation.organization.unblocked', actor: moderator, entity: organization,
            metadata: { reason: reason })
      organization
    end
  end
end
