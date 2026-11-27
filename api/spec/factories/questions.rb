# frozen_string_literal: true

FactoryBot.define do
  factory :question do
    association :author, factory: :user
    association :target, factory: :event
    text { 'Is parking available near the venue?' }
    is_hidden { false }

    trait :for_organization do
      association :target, factory: :organization
    end

    trait :for_platform do
      target { nil }
      target_type { 'Platform' }
      target_id { nil }
    end

    trait :hidden do
      is_hidden { true }
    end
  end
end
