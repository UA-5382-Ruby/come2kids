# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def confirmation(user, raw_token)
    @user = user
    @confirmation_url = "#{Rails.configuration.x.frontend_url}/confirm-email?#{{ token: raw_token }.to_query}"
    @expires_in_hours = Tokens::EmailConfirmation::TTL.in_hours.to_i

    I18n.with_locale(user.preferred_locale) do
      mail(to: user.email)
    end
  end
end
