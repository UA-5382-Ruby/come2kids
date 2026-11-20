# frozen_string_literal: true

FactoryBot.define do
  factory :order_item do
    association :order
    association :ticket_type
    quantity { 1 }
    unit_price { 1 }
  end
end
