class Role < ApplicationRecord
  # NOTE: ID зафіксовані в міграції CreateRoles (20261031073545)
  # NOTE: Це контракт схеми: partial indexes у company_members використовують ці значення
  OWNER_ID = 1
  MANAGER_ID = 2

  OWNER = "owner".freeze
  MANAGER = "manager".freeze

  has_many :company_members, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
end
