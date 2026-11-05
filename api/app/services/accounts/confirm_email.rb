module Accounts
  class ConfirmEmail
    def self.call(raw_token)
      new(raw_token).call
    end

    def initialize(raw_token)
      @raw_token = raw_token
    end

    def call
      user_id = Tokens::EmailConfirmation.consume(@raw_token)
      user = User.find_by(id: user_id)
      raise ApiError.new(:token_invalid) if user.nil?

      user.update!(email_confirmed_at: Time.current) unless user.email_confirmed?
      user
    end
  end
end
