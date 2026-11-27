# frozen_string_literal: true

class Event < ApplicationRecord
  STATUSES = %w[draft under_review published rejected cancelled cancelled_by_organizer].freeze
  LOCATION_TYPES = %w[offline online].freeze

  belongs_to :organization
  belongs_to :category, optional: true
  belongs_to :created_by, class_name: 'User'
  belongs_to :reviewed_by, class_name: 'User', optional: true

  has_many :event_translations, dependent: :destroy
  has_many :event_media, class_name: 'EventMedia', dependent: :destroy
  has_many :ticket_types, dependent: :destroy
  has_many :event_status_histories, dependent: :destroy
  has_many :event_revisions, dependent: :destroy
  has_many :event_reviews, dependent: :destroy
  has_many :subscriptions, as: :target, dependent: :delete_all
  has_many :event_reminders, dependent: :delete_all
  has_one :pending_revision, -> { where(status: 'under_review') }, class_name: 'EventRevision'

  validates :status, inclusion: { in: STATUSES }
  validates :location_type, inclusion: { in: LOCATION_TYPES }, allow_nil: true
  validate :end_after_start

  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :under_review, -> { where(status: 'under_review') }
  # Events the public may see (FR-EVT-1, FR-MOD-5): published, not deleted or cancelled,
  # and owned by an approved organization, so events of a blocked organization are hidden.
  scope :publicly_visible, lambda {
    published.where(deleted_at: nil, cancelled_at: nil)
             .joins(:organization).merge(Organization.publicly_visible)
  }

  def published?
    status == 'published'
  end

  def draft?
    status == 'draft'
  end

  def under_review?
    status == 'under_review'
  end

  # FR-MOD-5: ticket sales stop while the organization is blocked and resume after it is unblocked.
  # The order flow (EPIC-7) must check this before reserving tickets.
  def ticket_sales_open?
    published? && deleted_at.nil? && cancelled_at.nil? && organization.accepts_event_changes?
  end

  # The title in the given locale, falling back to Ukrainian (FR-I18N).
  def title(locale = I18n.locale)
    translations = event_translations.index_by(&:locale)
    (translations[locale.to_s] || translations['uk'] || translations.values.first)&.title
  end

  private

  def end_after_start
    return if start_at.blank? || end_at.blank?
    errors.add(:end_at, 'must be after start_at') if end_at <= start_at
  end
end
