# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    association :user
    association :event
    total_amount { 100 }
    currency { 'UAH' }
    status { 'pending' }
    sequence(:idempotency_key) { |n| "idem-key-#{n}" }
    reserved_until { 15.minutes.from_now }
  end
end
