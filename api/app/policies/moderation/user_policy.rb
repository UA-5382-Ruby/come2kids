# frozen_string_literal: true

module Moderation
  # Block/unblock users (US-6.3). Blocking another moderator is a business rule
  # (Moderation::BlockUser answers CANNOT_BLOCK_MODERATOR), not a permission question.
  class UserPolicy < BasePolicy
    def block?
      moderator?
    end
  end
end
