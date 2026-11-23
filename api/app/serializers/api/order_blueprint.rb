# frozen_string_literal: true

module Api
  class OrderBlueprint < Blueprinter::Base
    identifier :id
    fields :event_id, :status, :currency

    field :amountMinor do |order|
      order.total_amount
    end

    field :reserved_until do |order|
      order.reserved_until&.utc&.iso8601(3)
    end

    field :created_at do |order|
      order.created_at&.utc&.iso8601(3)
    end

    association :tickets, blueprint: Api::TicketBlueprint
  end
end
