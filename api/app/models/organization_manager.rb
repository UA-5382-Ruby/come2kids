class OrganizationManager < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :added_by, class_name: "User", optional: true

  validate :user_is_not_owner

  private

  def user_is_not_owner
    return unless organization && organization.owner_id == user_id
    errors.add(:user_id, :owner_cannot_be_manager)
  end
end
