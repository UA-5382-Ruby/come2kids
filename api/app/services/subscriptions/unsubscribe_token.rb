# frozen_string_literal: true

module Subscriptions
  # Signed token for the one-click unsubscribe link in emails (FR-SUB-4).
  # It carries only the subscription id and does not expire. A token of a deleted subscription still
  # verifies but finds nothing, so a repeated click is harmless.
  class UnsubscribeToken
    PURPOSE = :unsubscribe

    def self.generate(subscription)
      verifier.generate(subscription.id, purpose: PURPOSE)
    end

    # The subscription id, or nil when the token is missing, tampered with or made for another purpose.
    def self.verify(token)
      return if token.blank?

      verifier.verified(token.to_s, purpose: PURPOSE)
    end

    def self.verifier
      Rails.application.message_verifier('subscriptions/unsubscribe')
    end

    private_class_method :verifier
  end
end
