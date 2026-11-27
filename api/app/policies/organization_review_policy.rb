# frozen_string_literal: true

class OrganizationReviewPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    user.present? && user.email_confirmed? && !user.blocked?
  end

  def update?
    user.present? && !user.blocked? && record.user_id == user.id
  end

  def destroy?
    update?
  end
end
