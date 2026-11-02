class RefreshToken < ApplicationRecord
  belongs_to :user

  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def active?
    !revoked? && !expired?
  end
end
