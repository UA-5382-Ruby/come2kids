# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch('MAIL_FROM', 'noreply@come2kids.local') }
  layout 'mailer'
  self.delivery_job = MailDeliveryJob
end
