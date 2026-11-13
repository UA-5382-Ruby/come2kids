# frozen_string_literal: true

module Accounts
  class ForgotPassword
    def self.call(email)
      new(email).call
    end

    def initialize(email)
      @email = email.to_s.strip.downcase
    end

    def call
      user = User.find_by(email: @email)

      if user && !user.blocked?
        if Tokens::PasswordReset.acquire_cooldown(user)
          raw_token = Tokens::PasswordReset.issue(user)
          UserMailer.password_reset(user, raw_token).deliver_later
        end
      end

      true
    end
  end
end
