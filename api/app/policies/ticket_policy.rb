# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def my?
    user.present?
  end

  def show?
    user.present? && record.user_id == user.id
  end
end
