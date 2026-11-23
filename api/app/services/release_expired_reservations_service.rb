# frozen_string_literal: true

class ReleaseExpiredReservationsService
  include Dry::Monads[:result]

  def self.call(now: Time.current)
    new(now: now).call
  end

  def initialize(now: Time.current)
    @now = now
  end

  def call
    released_count = 0

    Order.expired_reservations(@now).pluck(:id).each do |order_id|
      released_count += 1 if release_order(order_id)
    end

    Success(released_count)
  rescue StandardError => e
    Failure(e)
  end

  private

  def release_order(order_id)
    Order.transaction do
      order = Order.lock.find(order_id)
      return false unless expired_pending?(order)

      release_items(order)
      order.update!(status: :expired)
      true
    end
  end

  def expired_pending?(order)
    order.pending? && order.reserved_until.present? && order.reserved_until <= @now
  end

  def release_items(order)
    order.order_items.order(:ticket_type_id).each do |item|
      ticket_type = TicketType.lock.find(item.ticket_type_id)
      new_sold = [ ticket_type.sold_quantity - item.quantity, 0 ].max
      ticket_type.update!(sold_quantity: new_sold)
    end
  end
end
