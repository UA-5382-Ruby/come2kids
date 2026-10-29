class Event < ApplicationRecord
  STATUSES = %w[draft under_review published rejected cancelled].freeze
  LOCATION_TYPES = %w[offline online].freeze

  belongs_to :organization
  belongs_to :category, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :event_translations, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :location_type, inclusion: { in: LOCATION_TYPES }, allow_nil: true
  validate :end_after_start

  scope :published, -> { where(status: "published") }
  scope :draft, -> { where(status: "draft") }

  def published?
    status == "published"
  end

  def draft?
    status == "draft"
  end

  private

  def end_after_start
    return if start_at.blank? || end_at.blank?
    errors.add(:end_at, "must be after start_at") if end_at <= start_at
  end
end
