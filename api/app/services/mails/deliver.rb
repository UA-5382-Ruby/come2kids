# frozen_string_literal: true

module Mails
  # Builds and delivers a mailer message. Returns Dry::Monads::Result (US-1.4 scope).
  class Deliver
    include Dry::Monads[:result]

    def self.call(mailer:, mail_method:, delivery_method:, args: [], kwargs: nil, params: nil)
      new(
        mailer: mailer,
        mail_method: mail_method,
        delivery_method: delivery_method,
        args: args,
        kwargs: kwargs,
        params: params,
      ).call
    end

    def initialize(mailer:, mail_method:, delivery_method:, args:, kwargs:, params:)
      @mailer = mailer
      @mail_method = mail_method
      @delivery_method = delivery_method
      @args = args || []
      @kwargs = kwargs
      @params = params
    end

    def call
      mailer_class = @mailer.constantize
      mailer_instance = @params.present? ? mailer_class.with(**@params.symbolize_keys) : mailer_class
      message = if @kwargs.present?
                  mailer_instance.public_send(@mail_method, *@args, **@kwargs.symbolize_keys)
      else
                  mailer_instance.public_send(@mail_method, *@args)
      end
      message.send(@delivery_method)
      Success(message)
    rescue StandardError => e
      Failure(e)
    end
  end
end
