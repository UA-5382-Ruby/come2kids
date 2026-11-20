# frozen_string_literal: true

class EventMedia < ApplicationRecord
  self.table_name = 'event_media'

  KINDS = %w[banner gallery].freeze
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_BYTE_SIZE = Integer(ENV.fetch('EVENT_MEDIA_MAX_BYTE_SIZE', 5.megabytes))
  MAX_GALLERY_IMAGES = Integer(ENV.fetch('EVENT_MEDIA_MAX_GALLERY_IMAGES', 10))

  def self.file_too_large_message
    "must be less than #{MAX_BYTE_SIZE} bytes"
  end

  def self.gallery_limit_message
    "gallery cannot have more than #{MAX_GALLERY_IMAGES} images"
  end

  belongs_to :event
  has_one_attached :file, dependent: :purge

  validates :kind, inclusion: { in: KINDS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :acceptable_file
  validate :only_one_banner, on: :create
  validate :gallery_within_limit, on: :create

  scope :banner, -> { where(kind: 'banner') }
  scope :gallery, -> { where(kind: 'gallery').order(:position, :id) }

  private

  def acceptable_file
    unless file.attached?
      errors.add(:file, 'must be attached')
      return
    end

    errors.add(:file, self.class.file_too_large_message) if file.blob.byte_size > MAX_BYTE_SIZE
    return if CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, 'must be JPEG, PNG, or WEBP')
  end

  def only_one_banner
    return unless kind == 'banner' && event.present?
    return unless event.event_media.banner.exists?

    errors.add(:kind, 'already has a banner')
  end

  def gallery_within_limit
    return unless kind == 'gallery' && event.present?
    return if event.event_media.gallery.count < MAX_GALLERY_IMAGES

    errors.add(:file, self.class.gallery_limit_message)
  end
end
