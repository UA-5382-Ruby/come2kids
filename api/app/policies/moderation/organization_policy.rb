# frozen_string_literal: true

module Moderation
  # Organization queue, approve/reject (US-6.1) and block/unblock (US-6.4).
  class OrganizationPolicy < BasePolicy
    def block?
      moderator?
    end
  end
end
