# frozen_string_literal: true

# Who may appeal a block (FR-APP-1, FR-APP-2). The record is an Appeal built for the target:
# - a user appeals their own block (with the appeal token they received at login);
# - only the owner appeals for an organization; managers cannot.
# Whether the target is actually blocked is a business rule checked by Appeals::Submit.
class AppealPolicy < ApplicationPolicy
  def create?
    return false if guest?

    case record.target
    when User then record.target == user
    when Organization then owner_of?(record.target)
    else false
    end
  end

  # Checking the appeal status follows the same rule as submitting one (FR-APP-7).
  def current?
    create?
  end
end
