class Organization < ApplicationRecord
  STATUSES = %w[pending_approval approved rejected blocked].freeze

  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :blocked_by, class_name: "User", optional: true

  has_many :organization_translations, dependent: :destroy
  has_many :events, dependent: :restrict_with_error
  has_many :company_members, dependent: :destroy

  # NOTE: Менеджери: тільки membership з role_id = MANAGER_ID
  # Якщо в майбутньому з'являться нові ролі (бухгалтер, редактор),
  # потрібно буде оновити цей scope або додати флаг can_manage_events у таблицю roles
  has_many :managers, -> { where(role_id: Role::MANAGER_ID) },
           through: :company_members, source: :user

  # NOTE: Власник через membership з role_id = OWNER_ID
  has_one :owner_membership, -> { where(role_id: Role::OWNER_ID) },
          class_name: "CompanyMember"
  has_one :owner, through: :owner_membership, source: :user

  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :contact_email, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rejection_reason, presence: true, if: -> { status == "rejected" }
  validates :approved_at, presence: true, if: -> { status == "approved" }

  scope :approved, -> { where(status: "approved") }
  scope :pending, -> { where(status: "pending_approval") }

  def approved?
    status == "approved"
  end

  def blocked?
    status == "blocked"
  end
end
