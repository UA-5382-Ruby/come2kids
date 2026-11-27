# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def my?
    user.present?
  end

  def show?
    user.present? && record.user_id == user.id
  end

  def qr?
    record.user_id == user.id
  end

  def pdf?
    record.user_id == user.id
  end
end
