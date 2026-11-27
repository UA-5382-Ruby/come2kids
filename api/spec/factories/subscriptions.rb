# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    association :user
    association :target, factory: :event

    trait :organization do
      association :target, factory: :organization
    end
  end
end
