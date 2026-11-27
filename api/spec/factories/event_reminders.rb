# frozen_string_literal: true

FactoryBot.define do
  factory :event_reminder do
    association :event
    association :user
    sent_at { Time.current }
  end
end
