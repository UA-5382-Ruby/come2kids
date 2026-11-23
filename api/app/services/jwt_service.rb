# frozen_string_literal: true

# Encodes and decodes short-lived access tokens (FR-AUTH-4).
# Follows RFC 8725: the algorithm is pinned on decode, exp and iss are always verified.
class JwtService
  ALGORITHM = 'HS256'.freeze
  ISSUER = ENV.fetch('JWT_ISSUER', 'come2kids').freeze
  env_secret = ENV['JWT_SECRET'].presence
  SECRET_KEY = env_secret || Rails.application.secret_key_base
  ACCESS_TTL = ENV.fetch('JWT_ACCESS_TTL', 15.minutes.to_i).to_i.seconds
  # FR-APP-1: a blocked user gets a short-lived appeal token that only opens the appeal endpoints.
  APPEAL_TTL = ENV.fetch('JWT_APPEAL_TTL', 24.hours.to_i).to_i.seconds

  ACCESS_SCOPE = 'access'.freeze
  APPEAL_SCOPE = 'appeal'.freeze
  TTLS = { ACCESS_SCOPE => ACCESS_TTL, APPEAL_SCOPE => APPEAL_TTL }.freeze

  class InvalidToken < StandardError; end
  class ExpiredToken < InvalidToken; end

  class << self
    def encode(user, scope: ACCESS_SCOPE)
      ttl = TTLS.fetch(scope)
      now = Time.current.to_i
      payload = { sub: user.id.to_s, iss: ISSUER, iat: now, exp: now + ttl.to_i, jti: SecureRandom.uuid,
                  scope: scope }
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def encode_appeal(user)
      encode(user, scope: APPEAL_SCOPE)
    end

    # Tokens issued before scopes existed carry no scope claim and are access tokens.
    def scope_of(payload)
      payload['scope'].presence || ACCESS_SCOPE
    end

    # Returns the payload hash or raises InvalidToken / ExpiredToken.
    def decode(token)
      payload, _header = JWT.decode(token, SECRET_KEY, true,
        algorithm: ALGORITHM, iss: ISSUER, verify_iss: true, verify_iat: true, required_claims: %w[sub exp])
      payload
    rescue JWT::ExpiredSignature
      raise ExpiredToken, 'Access token has expired'
    rescue JWT::DecodeError
      raise InvalidToken, 'Access token is invalid'
    end
  end
end
