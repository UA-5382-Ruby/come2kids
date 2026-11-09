# frozen_string_literal: true

module Accounts
  class Register
    def self.call(attributes)
      new(attributes).call
    end

    def initialize(attributes)
      @attributes = attributes
    end

    def call
      user = User.create!(@attributes)

      Tokens::EmailConfirmation.acquire_cooldown(user)
      raw_token = Tokens::EmailConfirmation.issue(user)

      UserMailer.confirmation(user, raw_token).deliver_later
      user
    rescue ActiveRecord::RecordNotUnique
      duplicate = User.new(@attributes.slice(:email))
      duplicate.errors.add(:email, :taken)
      raise ActiveRecord::RecordInvalid, duplicate
    end
  end
end
