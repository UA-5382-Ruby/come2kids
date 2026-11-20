# frozen_string_literal: true

module Events
  # Recipient ids for a cancellation notice. Does not send mail.
  # Ticket holders come from tickets; subscribers come from subscriptions.
  # Either list stays empty until that table exists.
  class CancellationNotice
    def self.recipient_ids(event)
      (holder_ids(event) + subscriber_ids(event)).uniq
    end

    def self.holder_ids(event)
      return [] unless table?('tickets')

      if column?('tickets', 'event_id') && column?('tickets', 'user_id')
        ids('SELECT DISTINCT user_id FROM tickets WHERE event_id = ?', event.id)
      elsif table?('order_items') && table?('orders')
        ids(holders_through_orders_sql, event.id)
      else
        []
      end
    end

    def self.subscriber_ids(event)
      return [] unless table?('subscriptions')
      return [] unless column?('subscriptions', 'target_type') && column?('subscriptions', 'target_id')

      ids(<<~SQL.squish, event.id)
        SELECT DISTINCT user_id FROM subscriptions
        WHERE target_type = 'Event' AND target_id = ?
      SQL
    end

    def self.holders_through_orders_sql
      <<~SQL.squish
        SELECT DISTINCT orders.user_id FROM tickets
        INNER JOIN order_items ON order_items.id = tickets.order_item_id
        INNER JOIN orders ON orders.id = order_items.order_id
        WHERE orders.event_id = ?
      SQL
    end

    def self.ids(sql, *binds)
      query = ActiveRecord::Base.sanitize_sql_array([ sql, *binds ])
      ActiveRecord::Base.connection.select_values(query)
    end

    def self.table?(name)
      ActiveRecord::Base.connection.data_source_exists?(name)
    end

    def self.column?(table, column)
      ActiveRecord::Base.connection.column_exists?(table, column)
    end

    private_class_method :holders_through_orders_sql, :ids, :table?, :column?
  end
end
