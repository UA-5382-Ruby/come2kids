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

  def password_reset(user, raw_token)
    @user = user
    @reset_url = "#{Rails.configuration.x.frontend_url}/reset-password?#{{ token: raw_token }.to_query}"
    @expires_in_hours = Tokens::PasswordReset::TTL.in_hours.to_i

    I18n.with_locale(user.preferred_locale) do
      mail(to: user.email)
    end
  end

  def manager_added(user, organization, added_by)
    @user = user
    @organization_name = organization.organization_translations.find_by(locale: I18n.locale)&.name || organization.slug
    @added_by_name = "#{added_by.first_name} #{added_by.last_name}"

    I18n.with_locale(user.preferred_locale) do
      mail(to: user.email, subject: I18n.t('user_mailer.manager_added.subject', org_name: @organization_name))
    end
  end
end
