class User < ApplicationRecord
  has_secure_password

  LOCALES = %w[uk en].freeze
  ROLES = %w[user moderator].freeze

  belongs_to :blocked_by, class_name: "User", optional: true

  has_many :company_members, dependent: :destroy
  has_many :organizations, through: :company_members

  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true, length: { maximum: 100 }
  validates :preferred_locale, inclusion: { in: LOCALES }
  validates :platform_role, inclusion: { in: ROLES }
  validates :block_reason, presence: true, if: :blocked?
  validate :password_complexity, if: -> { password_digest_changed? }

  scope :active, -> { where(is_active: true) }
  scope :not_blocked, -> { where(blocked_at: nil) }

  def blocked?
    blocked_at.present?
  end

  def moderator?
    platform_role == "moderator"
  end

  def email_confirmed?
    email_confirmed_at.present?
  end

  # Roles in organizations keyed by organization id, e.g. { 5 => "owner", 8 => "manager" } (US-2.4).
  # Memoized, so every authorization check in one request shares a single query.
  def organization_roles
    @organization_roles ||= company_members.joins(:role).pluck(:organization_id, "roles.key").to_h
  end

  # "owner", "manager" or nil when the user has no role in the organization.
  def role_in(organization)
    organization_roles[organization.id] if organization
  end

  def owner_of?(organization)
    role_in(organization) == Role::OWNER
  end

  def manager_of?(organization)
    role_in(organization) == Role::MANAGER
  end

  def reload(*)
    @organization_roles = nil
    super
  end

  private

  def password_complexity
    return if password.blank? || password.match?(/\A(?=.*[A-Za-z])(?=.*\d).{8,}\z/)
    errors.add(:password, :complexity)
  end
end
