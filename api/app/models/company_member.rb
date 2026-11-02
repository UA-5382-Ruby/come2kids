class CompanyMember < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :role
  belongs_to :added_by, class_name: "User", optional: true

  validates :role_id, presence: true
  validates :user_id, uniqueness: { scope: :organization_id,
                                    message: "уже є членом цієї організації" }
end
