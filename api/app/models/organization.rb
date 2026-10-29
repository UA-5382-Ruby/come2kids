class Organization < ApplicationRecord
  STATUSES = %w[pending_approval approved rejected blocked].freeze

  belongs_to :owner, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :blocked_by, class_name: "User", optional: true

  has_many :organization_managers, dependent: :destroy
  has_many :managers, through: :organization_managers, source: :user
  has_many :organization_translations, dependent: :destroy
  has_many :events, dependent: :restrict_with_error

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
