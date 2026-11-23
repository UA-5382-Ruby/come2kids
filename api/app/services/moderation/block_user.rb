# frozen_string_literal: true

module Moderation
  # Blocks a user (US-6.3, FR-MOD-4, FR-MOD-7). A blocked user cannot authenticate any more:
  # Authenticatable rejects their access tokens on every request, so tokens issued before the block stop
  # working at once (the API has no refresh tokens to revoke). Their data is kept.
  class BlockUser < Action
    def initialize(user:, moderator:, reason:)
      super()
      @user = user
      @moderator = moderator
      @reason = normalize_reason(reason)
    end

    private

    attr_reader :user, :moderator, :reason

    def perform
      require_reason!(reason)
      fail!(Api::ErrorCodes::CANNOT_BLOCK_MODERATOR, 'cannot_block_moderator') if user.moderator?

      user.lock!
      invalid_transition!(user, 'blocked') if user.blocked?

      user.update!(blocked_at: Time.current, blocked_by: moderator, block_reason: reason)
      ModerationLog.record!(entity: user, moderator: moderator, decision: :blocked, reason: reason)

      notify(:user_block_changed, user, 'blocked', reason)
      track(action: 'moderation.user.blocked', actor: moderator, entity: user, metadata: { reason: reason })
      user
    end
  end
end
