# frozen_string_literal: true

module Accounts
  class ResetPassword
    def self.call(raw_token, new_password, password_confirmation)
      new(raw_token, new_password, password_confirmation).call
    end

    def initialize(raw_token, new_password, password_confirmation)
      @raw_token = raw_token
      @new_password = new_password
      @password_confirmation = password_confirmation
    end

    def call
      user_id = Tokens::PasswordReset.consume(@raw_token)
      user = User.find_by(id: user_id)

      raise ApiError.new(:token_invalid) if user.nil?

      # Використовуємо update! щоб спрацював rescue в контролері при помилці валідації
      user.update!(password: @new_password, password_confirmation: @password_confirmation)

      revoke_refresh_tokens(user)

      user
    end

    private

    def revoke_refresh_tokens(user)
      # БЕЗПЕЧНА ЗАГЛУШКА: просто логуємо, щоб уникнути 500 помилок
      # Пізніше тут буде реальна логіка видалення з Redis
      Rails.logger.info("[ResetPassword] Mock revoking refresh tokens for user #{user.id}")
    end
  end
end
