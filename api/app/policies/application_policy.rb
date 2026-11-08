# frozen_string_literal: true

# Deny-by-default base policy (US-2.4). Subclasses allow actions explicitly, following the
# permission matrix (Technical Requirements, section 2.1). `user` is nil for a guest.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end

    private

    attr_reader :user, :scope
  end

  private

  def guest?
    user.nil?
  end

  def moderator?
    user.present? && user.moderator?
  end

  # Ownership checks always use the organization of the resource itself,
  # so a manager of organization A never passes a check on organization B.
  def owner_of?(resource = record)
    user.present? && user.owner_of?(organization_for(resource))
  end

  def manager_of?(resource = record)
    user.present? && user.manager_of?(organization_for(resource))
  end

  # Owners keep every manager permission (Technical Requirements, section 2).
  def organization_member?(resource = record)
    owner_of?(resource) || manager_of?(resource)
  end

  # The organization a resource belongs to: the organization itself or `resource.organization`.
  # Returns nil for a class (e.g. `authorize Event`) or anything without an organization.
  def organization_for(resource)
    return resource if resource.is_a?(Organization)

    resource.organization if resource.respond_to?(:organization)
  end
end
