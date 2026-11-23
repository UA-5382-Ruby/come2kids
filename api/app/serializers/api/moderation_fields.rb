# frozen_string_literal: true

module Api
  # Shared helpers for the moderation blueprints: UTC ISO 8601 timestamps and short user summaries.
  module ModerationFields
    module_function

    def time(value)
      value&.utc&.iso8601(3)
    end

    def user_summary(user)
      return if user.nil?

      { id: user.id, email: user.email, first_name: user.first_name, last_name: user.last_name }
    end
  end
end
