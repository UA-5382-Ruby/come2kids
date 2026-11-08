# frozen_string_literal: true

module Tokens
  class EmailConfirmation
    TTL = 24.hours
    COOLDOWN = 60.seconds

    class << self
      attr_writer :redis

      def redis
        @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      end

      def issue(user)
        revoke(user)
        raw_token = SecureRandom.urlsafe_base64(32)
        digest = digest(raw_token)

        redis.set(token_key(digest), user.id, ex: TTL.to_i)
        redis.set(user_key(user.id), digest, ex: TTL.to_i)
        raw_token
      end

      def consume(raw_token)
        digest = digest(raw_token)
        user_id = redis.getdel(token_key(digest))

        if user_id.nil?
          raise ApiError.new(:token_used) if redis.exists?(used_key(digest))
          raise ApiError.new(:token_invalid)
        end

        redis.set(used_key(digest), 1, ex: TTL.to_i)
        redis.del(user_key(user_id))
        user_id.to_i
      end

      def acquire_cooldown(user)
        redis.set(cooldown_key(user.id), 1, nx: true, ex: COOLDOWN.to_i) ? true : false
      end

      def digest(raw_token)
        Digest::SHA256.hexdigest(raw_token.to_s)
      end

      def token_key(digest) = "email_confirmation:token:#{digest}"
      def user_key(user_id) = "email_confirmation:user:#{user_id}"
      def used_key(digest) = "email_confirmation:used:#{digest}"
      def cooldown_key(user_id) = "email_confirmation:cooldown:#{user_id}"

      private

      def revoke(user)
        old_digest = redis.get(user_key(user.id))
        redis.del(token_key(old_digest)) if old_digest
      end
    end
  end
end
