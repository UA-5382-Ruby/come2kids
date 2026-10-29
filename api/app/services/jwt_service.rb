# Encodes and decodes short-lived access tokens (FR-AUTH-4).
# Follows RFC 8725: the algorithm is pinned on decode, exp and iss are always verified.
class JwtService
  ALGORITHM = "HS256".freeze
  ISSUER = "come2kids".freeze

  class InvalidToken < StandardError; end
  class ExpiredToken < InvalidToken; end

  class << self
    def access_ttl
      ENV.fetch("JWT_ACCESS_TTL", 15.minutes.to_i).to_i.seconds
    end

    def encode(user)
      now = Time.current.to_i
      payload = { sub: user.id.to_s, iss: ISSUER, iat: now, exp: now + access_ttl.to_i, jti: SecureRandom.uuid }
      JWT.encode(payload, secret, ALGORITHM)
    end

    # Returns the payload hash or raises InvalidToken / ExpiredToken.
    def decode(token)
      payload, _header = JWT.decode(token, secret, true,
        algorithm: ALGORITHM, iss: ISSUER, verify_iss: true, verify_iat: true, required_claims: %w[sub exp])
      payload
    rescue JWT::ExpiredSignature
      raise ExpiredToken, "Access token has expired"
    rescue JWT::DecodeError
      raise InvalidToken, "Access token is invalid"
    end

    private

    def secret
      ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
    end
  end
end
