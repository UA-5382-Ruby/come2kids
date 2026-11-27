# frozen_string_literal: true

module Emails
  class EnqueuePurchase
    include Dry::Monads[:result]

    TEMPLATE = 'ticket_purchase'

    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      EmailOutbox.create!(
        to_email: @order.user.email,
        template: TEMPLATE,
        dedup_key: "#{TEMPLATE}:#{@order.id}",
        payload: { 'order_id' => @order.id }
      )
      Success(:enqueued)
    rescue ActiveRecord::RecordNotUnique
      Success(:duplicate)
    rescue StandardError => e
      Failure(e)
    end
  end
end
