# frozen_string_literal: true

# Per-request context for audit records (activity log) written outside the controller.
class Current < ActiveSupport::CurrentAttributes
  attribute :ip, :user_agent, :request_id
end
