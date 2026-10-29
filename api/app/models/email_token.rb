class EmailToken < ApplicationRecord
  PURPOSES = %w[confirmation reset].freeze

  belongs_to :user

  validates :purpose, inclusion: { in: PURPOSES }
  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def used?
    used_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def active?
    !used? && !expired?
  end
end
