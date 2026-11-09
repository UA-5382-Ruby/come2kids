# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    password { "Password123" }
    preferred_locale { "uk" }
    platform_role { "user" }
    is_active { true }
    email_confirmed_at { Time.current }

    trait :confirmed do
      email_confirmed_at { Time.current }
    end

    trait :unconfirmed do
      email_confirmed_at { nil }
    end

    trait :blocked do
      blocked_at { Time.current }
      block_reason { "Spam" }
    end

    trait :moderator do
      platform_role { "moderator" }
    end

    trait :deleted do
      deleted_at { Time.current }
    end

    trait :moderator do
      platform_role { "moderator" }
    end
  end
end
