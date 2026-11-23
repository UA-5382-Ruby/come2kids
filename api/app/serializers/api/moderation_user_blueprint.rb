# frozen_string_literal: true

module Api
  # A user with block details, returned by the block/unblock endpoints (US-6.3).
  class ModerationUserBlueprint < Blueprinter::Base
    identifier :id

    fields :email, :first_name, :last_name, :platform_role, :is_active, :block_reason, :blocked_by_id

    field(:blocked) { |user| user.blocked? }
    field(:blocked_at) { |user| ModerationFields.time(user.blocked_at) }
  end
end
