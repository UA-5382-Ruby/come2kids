
# frozen_string_literal: true

class OrderCreationService
  class EventNotPublishedError < StandardError; end
  class TicketsSoldOutError < StandardError; end
  class IdempotencyConflictError < StandardError; end
  class InvalidQuantityError < StandardError; end

  RESERVATION_TTL = 15.minutes

  def initialize(user:, event:, ticket_type_id:, quantity:, idempotency_key: nil)
    @user = user
    @event = event
    @ticket_type_id = ticket_type_id
    @quantity = quantity
    @idempotency_key = idempotency_key
  end

  def call
    unless (@quantity.is_a?(Integer) && @quantity.positive?) ||
           (@quantity.is_a?(String) && @quantity.match?(/\A[0-9]+\z/) && @quantity.to_i.positive?)
      raise InvalidQuantityError, 'Quantity must be greater than zero'
    end
    @quantity = @quantity.to_i

    existing_order = find_existing_order
    return existing_order if existing_order

    # FR-MOD-5: sales also stop while the organization is blocked (or the event is cancelled/deleted).
    raise EventNotPublishedError, 'Ticket sales are closed for this event' unless @event.ticket_sales_open?

    Order.transaction do
      if @idempotency_key.present?
        # Serialize all requests for a globally unique key, including different ticket types.
        connection = Order.connection
        connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(@idempotency_key)}, 0))")
        existing_order = find_existing_order
        next existing_order if existing_order
      end

      ticket_type = @event.ticket_types.lock.find(@ticket_type_id)

      if ticket_type.sold_quantity + @quantity > ticket_type.total_quantity
        raise TicketsSoldOutError, 'Not enough tickets available'
      end

      total_amount = ticket_type.price * @quantity
      status = total_amount.zero? ? 'paid' : 'pending'
      reserved_until = status == 'pending' ? RESERVATION_TTL.from_now : nil

      order = Order.create!(
        user: @user,
        event: @event,
        total_amount: total_amount,
        currency: ticket_type.currency,
        status: status,
        idempotency_key: @idempotency_key,
        reserved_until: reserved_until
      )

    order_item = order.order_items.create!(
        ticket_type: ticket_type,
        quantity: @quantity,
        unit_price: ticket_type.price
      )

      ticket_type.update!(sold_quantity: ticket_type.sold_quantity + @quantity)

      issue_tickets(order_item) if order.paid?

      order
    end
  end

  private

  def find_existing_order
    return if @idempotency_key.blank?

    order = Order.find_by(idempotency_key: @idempotency_key)
    if order && order.user_id != @user.id
      raise IdempotencyConflictError, 'Idempotency key is already in use'
    end
    order
  end
  def issue_tickets(order_item)
    @quantity.times do
      order_item.tickets.create!(
        user: @user,
        event: @event
      )
    end
  end
end
