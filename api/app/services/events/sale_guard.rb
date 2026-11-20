# frozen_string_literal: true

module Events
  # Whether a new order may be opened for an event.
  # EPIC-7 calls this before creating an order.
  class SaleGuard
    def self.open?(event)
      event.published? && event.deleted_at.nil?
    end
  end
end
