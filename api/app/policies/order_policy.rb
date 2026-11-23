# frozen_string_literal: true


class OrderPolicy < ApplicationPolicy
  def create?
    user.present? && user.email_confirmed? && user.is_active? &&
      user.deleted_at.nil? && !user.blocked?
  end

  def my?
    user.present?
  end

  def show?
    user.present? && record.user_id == user.id
  end
end
