# frozen_string_literal: true

FactoryBot.define do
  factory :event_review do
    association :event, :past
    association :user
    rating { 5 }
    text { 'Чудова подія!' }
  end
end
