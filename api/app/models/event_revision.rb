# frozen_string_literal: true

class EventRevision < ApplicationRecord
  STATUSES = %w[under_review approved rejected withdrawn].freeze

  belongs_to :event
  belongs_to :submitted_by, class_name: 'User'
  belongs_to :reviewed_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }
  validate :payload_is_a_hash

  scope :pending, -> { where(status: 'under_review') }

  def pending?
    status == 'under_review'
  end

  private

  def payload_is_a_hash
    return if payload.is_a?(Hash)

    errors.add(:payload, 'must be an object')
  end
end
