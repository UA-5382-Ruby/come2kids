# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  EDITABLE_STATUSES = %w[draft rejected].freeze

  # FR-ORG-2, FR-MOD-5: only staff of an approved, not deleted organization may create events;
  # pending, rejected and blocked organizations cannot.
  def create?
    organization = organization_for(record)
    return false unless organization&.accepts_event_changes?

    organization_member?(record)
  end

  # Draft and rejected events can be edited by staff of an organization that may still change events.
  def update?
    editable_event?
  end

  # Media follows the same rule as editing (approved, not blocked or deleted organization; editable status).
  def manage_media?
    editable_event?
  end

  def submit?
    create?
  end

  def destroy?
    organization = organization_for(record)
    return false unless organization&.accepts_event_changes?

    organization_member?(record)
  end

  def index?
    organization_member?(record)
  end

  def participants?
    organization_member?(record)
  end

  def revise?
    return false unless organization_for(record)&.approved?
    return false unless organization_member?(record)

    record.published?
  end

  private

  def editable_event?
    organization = organization_for(record)
    return false unless organization&.accepts_event_changes?
    return false unless organization_member?(record)

    EDITABLE_STATUSES.include?(record.status)
  end
end
