# frozen_string_literal: true

module Events
  # Issued tickets plus active pending reservations for one ticket type.
  # Both counts stay at zero until the EPIC-7 tables exist.
  class TicketDemand
    def self.for(ticket_type_id)
      return 0 if ticket_type_id.blank?

      issued(ticket_type_id) + reserved(ticket_type_id)
    end

    def self.issued(ticket_type_id)
      return 0 unless tables?('tickets', 'order_items')

      count(<<~SQL.squish, ticket_type_id)
        SELECT COUNT(*) FROM tickets
        INNER JOIN order_items ON order_items.id = tickets.order_item_id
        WHERE order_items.ticket_type_id = ?
      SQL
    end

    def self.reserved(ticket_type_id)
      return 0 unless tables?('orders', 'order_items')

      count(<<~SQL.squish, ticket_type_id, Time.current)
        SELECT COALESCE(SUM(order_items.quantity), 0) FROM order_items
        INNER JOIN orders ON orders.id = order_items.order_id
        WHERE order_items.ticket_type_id = ?
          AND orders.status = 'pending'
          AND (orders.reserved_until IS NULL OR orders.reserved_until > ?)
      SQL
    end

    def self.tables?(*names)
      names.all? { |name| ActiveRecord::Base.connection.data_source_exists?(name) }
    end

    def self.count(sql, *binds)
      ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql_array([ sql, *binds ])).to_i
    end
    private_class_method :tables?, :count
  end
end
