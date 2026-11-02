class OrganizationTranslation < ApplicationRecord
  LOCALES = %w[uk en].freeze

  belongs_to :organization

  validates :locale, inclusion: { in: LOCALES }
  validates :locale, uniqueness: { scope: :organization_id }
  validates :name, presence: true

  scope :uk, -> { where(locale: "uk") }
  scope :en, -> { where(locale: "en") }
end
