# frozen_string_literal: true

FactoryBot.define do
  factory :ticket do
    association :order_item
    user { order_item.order.user }
    event { order_item.order.event }
    status { 'valid' }
    issued_at { Time.current }
  end
end
