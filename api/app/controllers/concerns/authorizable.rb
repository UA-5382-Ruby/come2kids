# frozen_string_literal: true

# Pundit policies for every controller (US-2.4). Deny by default: an action that neither calls
# `authorize` nor skips the check (`skip_after_action :verify_authorized`) raises
# Pundit::AuthorizationNotPerformedError, so a new endpoint cannot ship unprotected by accident.
module Authorizable
  extend ActiveSupport::Concern
  include Pundit::Authorization

  included do
    after_action :verify_authorized
    rescue_from Pundit::NotAuthorizedError, with: :render_not_authorized
  end

  private

  # A guest has to log in first (401); a logged-in user without the permission gets 403.
  def render_not_authorized
    return render_unauthorized if current_user.nil?

    render_error("FORBIDDEN", "You are not allowed to perform this action", status: :forbidden)
  end
end
