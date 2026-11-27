# frozen_string_literal: true

# Subscriptions (Technical Requirements, 2.1: every logged-in user may subscribe; US-12.1).
class SubscriptionPolicy < ApplicationPolicy
  def my?
    signed_in?
  end

  def create?
    signed_in?
  end

  def destroy?
    signed_in? && record.user_id == user.id
  end

  # The signed token in the email link is the proof of ownership, so guests may call it.
  def unsubscribe?
    true
  end

  private

  def signed_in?
    user.present? && !user.blocked?
  end
end
