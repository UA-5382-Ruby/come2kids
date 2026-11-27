# frozen_string_literal: true

class EmailOutbox < ApplicationRecord
  MAX_ATTEMPTS = 5

  validates :to_email, :template, :dedup_key, presence: true
  validates :status, inclusion: { in: %w[pending sent failed] }

  scope :due, -> { where(status: %w[pending failed]).where(attempts: ...MAX_ATTEMPTS) }
end
