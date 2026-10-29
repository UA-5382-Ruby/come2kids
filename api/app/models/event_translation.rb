class EventTranslation < ApplicationRecord
  LOCALES = %w[uk en].freeze

  belongs_to :event

  validates :locale, inclusion: { in: LOCALES }
  validates :locale, uniqueness: { scope: :event_id }
  validates :title, presence: true

  scope :uk, -> { where(locale: "uk") }
  scope :en, -> { where(locale: "en") }
end
