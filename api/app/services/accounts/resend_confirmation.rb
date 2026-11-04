module Accounts
  class ResendConfirmation
    def self.call(email)
      new(email).call
    end

    def initialize(email)
      @email = email.to_s.strip
    end

    def call
      user = User.find_by(email: @email)
      return unless user && !user.email_confirmed? && !user.blocked?
      return unless Tokens::EmailConfirmation.acquire_cooldown(user)

      raw_token = Tokens::EmailConfirmation.issue(user)
      UserMailer.confirmation(user, raw_token).deliver_later
    end
  end
end
