# frozen_string_literal: true

module Subscriptions
  # Who receives subscription emails (FR-SUB-2, FR-SUB-3, FR-REM-1). Every method returns a User relation
  # without blocked, deactivated or deleted accounts (FR-SUB-5). A user appears once even if they both
  # follow an event and hold tickets for it.
  class Audience
    def self.organization(organization)
      reachable.where(id: Subscription.for_target(organization).select(:user_id))
    end

    # Event subscribers and holders of valid tickets. Organization subscribers are not included.
    def self.event(event)
      reachable.where(id: Subscription.for_target(event).select(:user_id))
               .or(reachable.where(id: holders(event).select(:user_id)))
    end

    def self.holders(event)
      Ticket.status_valid.where(event_id: event.id)
    end

    def self.reachable
      User.active.not_blocked.where(deleted_at: nil)
    end
  end
end
