# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def create?
    !user.company_members.joins(:role).exists?(roles: { key: 'owner' })
  end

  def update?
    user.company_members
        .joins(:role)
        .exists?(organization: record, roles: { key: 'owner' })
  end
end
