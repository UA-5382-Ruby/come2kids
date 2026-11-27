# frozen_string_literal: true

class Organization < ApplicationRecord
  STATUSES = %w[pending_approval approved rejected blocked].freeze

  attr_accessor :owner_user
  after_create :assign_designated_owner

  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :blocked_by, class_name: 'User', optional: true

  has_many :organization_translations, dependent: :destroy
  has_many :events, dependent: :restrict_with_error
  has_many :company_members, dependent: :destroy
  has_many :appeals, as: :target, dependent: :destroy
  has_many :organization_reviews, dependent: :destroy

  # NOTE: Менеджери: тільки membership з role_id = MANAGER_ID
  # Якщо в майбутньому з'являться нові ролі (бухгалтер, редактор),
  # потрібно буде оновити цей scope або додати флаг can_manage_events у таблицю roles
  has_many :managers, -> { where(role_id: Role::MANAGER_ID) },
           through: :company_members, source: :user

  # NOTE: Власник через membership з role_id = OWNER_ID
  has_one :owner_membership, -> { where(role_id: Role::OWNER_ID) },
          class_name: 'CompanyMember'
  has_one :owner, through: :owner_membership, source: :user

  has_one_attached :logo

  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :contact_email, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rejection_reason, presence: true, if: -> { status == 'rejected' }
  validates :approved_at, presence: true, if: -> { status == 'approved' }
  validates :block_reason, presence: true, if: :blocked?

  scope :approved, -> { where(status: 'approved') }
  scope :pending, -> { where(status: 'pending_approval') }
  # FR-MOD-5: only approved, not deleted organizations are shown publicly. A blocked organization has the
  # status `blocked`, so this scope also hides blocked organizations and (through Event.publicly_visible) their events.
  scope :publicly_visible, -> { where(status: 'approved', deleted_at: nil) }

  def approved?
    status == 'approved'
  end

  def pending_approval?
    status == 'pending_approval'
  end

  def rejected?
    status == 'rejected'
  end

  def blocked?
    status == 'blocked'
  end

  # FR-ORG-2, FR-MOD-5: owners and managers may create, edit and publish events only while the
  # organization is approved; a blocked, pending or rejected organization cannot.
  def accepts_event_changes?
    approved? && deleted_at.nil?
  end

  # The name in the given locale, falling back to Ukrainian, then to the slug.
  def name(locale = I18n.locale)
    translations = organization_translations.index_by(&:locale)
    (translations[locale.to_s] || translations['uk'])&.name || slug
  end

  private

  def assign_designated_owner
    return if owner_user.blank?
    company_members.create!(user: owner_user, role_id: Role::OWNER_ID, added_by: nil)
  end
end
