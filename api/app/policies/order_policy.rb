# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def create?
    user.present? && user.email_confirmed? && user.is_active? &&
      user.deleted_at.nil? && !user.blocked?
  end
end
