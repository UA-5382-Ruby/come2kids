# Long-lived, revocable token used to obtain new access tokens (FR-AUTH-4).
# Only a SHA-256 digest is stored; the raw value is handed to the client once.
class RefreshToken < ApplicationRecord
  belongs_to :user
  belongs_to :replaced_by, class_name: "RefreshToken", optional: true

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  class << self
    def ttl
      ENV.fetch("REFRESH_TOKEN_TTL_DAYS", 30).to_i.days
    end

    # Returns [record, raw_token]. The raw token is never persisted.
    def issue_for(user)
      raw_token = SecureRandom.urlsafe_base64(32)
      record = create!(user: user, token_digest: digest(raw_token), expires_at: ttl.from_now)
      [ record, raw_token ]
    end

    def find_by_raw(raw_token)
      return if raw_token.blank?

      find_by(token_digest: digest(raw_token))
    end

    def revoke_all_for(user)
      user.with_lock do
        where(user: user, revoked_at: nil).update_all(revoked_at: Time.current, updated_at: Time.current)
      end
    end

    # A random 256-bit token does not need a slow hash; SHA-256 keeps lookups indexable.
    def digest(raw_token)
      OpenSSL::Digest::SHA256.hexdigest(raw_token)
    end
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !revoked? && !expired?
  end

  def revoke!(replaced_by: nil)
    update!(revoked_at: Time.current, replaced_by: replaced_by)
  end

  # Revokes this token and issues its successor. Returns [new_record, raw_token],
  # or nil when a concurrent request has already used or revoked this token.
  def rotate!
    user.with_lock do
      lock!
      next unless active?

      new_record, raw_token = self.class.issue_for(user)
      revoke!(replaced_by: new_record)
      [ new_record, raw_token ]
    end
  end
end
