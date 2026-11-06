# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password1" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email_confirmed_at { Time.current }

    trait :unconfirmed do
      email_confirmed_at { nil }
    end

    trait :blocked do
      blocked_at { Time.current }
      block_reason { "Spam" }
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
