# frozen_string_literal: true

# Active Job wrapper for ActionMailer deliveries (Sidekiq :mailers queue).
# Subclasses ActionMailer::MailDeliveryJob so `have_enqueued_mail` keeps working.
# Uses Dry::Monads::Result for the delivery attempt; exhausted failures go to Mongo.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  include LogsFailuresToMongo


  queue_as :mailers

  def failure_log_action
    'email.delivery_failed'
  end

  def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    result = Mails::Deliver.call(
      mailer: mailer,
      mail_method: mail_method,
      delivery_method: delivery_method,
      args: args,
      kwargs: kwargs,
      params: params,
    )
    return if result.success?

    raise result.failure
  end
end
