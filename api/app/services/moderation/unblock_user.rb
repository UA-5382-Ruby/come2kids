# frozen_string_literal: true

module Moderation
  # Unblocks a user and restores access (US-6.3, FR-MOD-4, FR-MOD-7).
  # Called directly by a moderator, or through an accepted appeal (Appeals::Decide passes notify: false,
  # because the appeal decision email already tells the user).
  class UnblockUser < Action
    def initialize(user:, moderator:, reason: nil, notify: true)
      super()
      @user = user
      @moderator = moderator
      @reason = normalize_reason(reason)
      @notify_user = notify
    end

    private

    attr_reader :user, :moderator, :reason

    def perform
      require_reason!(reason) if reason
      user.lock!
      fail!(Api::ErrorCodes::NOT_BLOCKED, 'not_blocked') unless user.blocked?

      user.update!(blocked_at: nil, blocked_by: nil, block_reason: nil)
      ModerationLog.record!(entity: user, moderator: moderator, decision: :unblocked, reason: reason)
      Appeal.close_open_for!(user, moderator: moderator, reason: reason)

      notify(:user_block_changed, user, 'unblocked', reason) if @notify_user
      track(action: 'moderation.user.unblocked', actor: moderator, entity: user, metadata: { reason: reason })
      user
    end
  end
end
