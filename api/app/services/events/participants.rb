# frozen_string_literal: true

module Events
  # One page of issued tickets for an organizer.
  # Returns an empty page until the tickets table exists.
  class Participants
    Row = Struct.new(:id, :holder_name, :ticket_type_name, :check_in_state, keyword_init: true)

    def self.page(event, page:, page_size:, search: nil)
      new(event, page:, page_size:, search:).call
    end

    def initialize(event, page:, page_size:, search:)
      @event = event
      @page = page
      @page_size = page_size
      @search = search.to_s.strip
    end

    def call
      return empty_page unless tickets_ready?

      total = connection.select_value(sanitize("SELECT COUNT(*) #{from_sql}", binds)).to_i
      rows = connection.select_all(sanitize("#{select_sql} #{from_sql} ORDER BY tickets.id DESC LIMIT ? OFFSET ?", binds + [ @page_size, offset ]))
      [ rows.map { |row| build_row(row) }, pagination(total) ]
    end

    private

    def empty_page
      [ [], pagination(0) ]
    end

    def tickets_ready?
      connection.data_source_exists?('tickets') && connection.column_exists?(:tickets, :event_id)
    end

    def select_sql
      <<~SQL.squish
        SELECT tickets.id,
               tickets.status AS check_in_state,
               TRIM(CONCAT(users.first_name, ' ', users.last_name)) AS holder_name,
               ticket_types.name AS ticket_type_name
      SQL
    end

    def from_sql
      sql = <<~SQL.squish
        FROM tickets
        LEFT JOIN users ON users.id = tickets.user_id
        LEFT JOIN order_items ON order_items.id = tickets.order_item_id
        LEFT JOIN ticket_types ON ticket_types.id = order_items.ticket_type_id
        WHERE tickets.event_id = ?
      SQL
      return sql if @search.blank?

      "#{sql} AND (users.first_name ILIKE ? OR users.last_name ILIKE ? OR tickets.code ILIKE ? OR ticket_types.name ILIKE ?)"
    end

    def binds
      values = [ @event.id ]
      values.concat([ "%#{@search}%" ] * 4) if @search.present?
      values
    end

    def build_row(row)
      Row.new(
        id: row['id'],
        holder_name: row['holder_name'].to_s.strip,
        ticket_type_name: row['ticket_type_name'],
        check_in_state: row['check_in_state'].presence || 'valid'
      )
    end

    def pagination(total)
      {
        page: @page,
        pageSize: @page_size,
        totalCount: total,
        totalPages: (total.to_f / @page_size).ceil
      }
    end

    def offset
      (@page - 1) * @page_size
    end

    def sanitize(sql, values)
      ActiveRecord::Base.sanitize_sql_array([ sql, *values ])
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
