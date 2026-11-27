# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def create?
    !user.company_members.joins(:role).exists?(roles: { key: 'owner' })
  end

  def update?
    owner?
  end

  def show_managers?
    owner? || manager?
  end

  def add_manager?
    owner?
  end

  def remove_manager?
    owner?
  end

  private

  def owner?
    user.company_members.exists?(organization: record, role: Role.find_by(key: 'owner'))
  end

  def manager?
    user.company_members.exists?(organization: record, role: Role.find_by(key: 'manager'))
  end

  def pending_approval?
    status == 'pending_approval'
  end

  def approved?
    status == 'approved'
  end
end
