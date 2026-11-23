# frozen_string_literal: true

module Moderation
  # Blocks an organization (US-6.4, FR-MOD-5, FR-MOD-7). The organization and its events disappear from
  # public lists (Organization.publicly_visible, Event.publicly_visible), ticket sales stop
  # (Event#ticket_sales_open?) and its staff cannot create or edit events (Organization#accepts_event_changes?).
  # Sold tickets stay valid; nothing is refunded and no data is deleted.
  class BlockOrganization < Action
    def initialize(organization:, moderator:, reason:)
      super()
      @organization = organization
      @moderator = moderator
      @reason = normalize_reason(reason)
    end

    private

    attr_reader :organization, :moderator, :reason

    def perform
      require_reason!(reason)
      organization.lock!
      invalid_transition!(organization) if organization.blocked?

      organization.update!(status: 'blocked', blocked_at: Time.current, blocked_by: moderator, block_reason: reason)
      ModerationLog.record!(entity: organization, moderator: moderator, decision: :blocked, reason: reason)

      notify(:organization_block_changed, organization, 'blocked', reason) if organization.owner
      track(action: 'moderation.organization.blocked', actor: moderator, entity: organization,
            metadata: { reason: reason })
      organization
    end
  end
end
