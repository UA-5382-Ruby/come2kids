# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    association :organization
    association :category
    association :created_by, factory: :user
    status { 'published' }
    location_type { 'offline' }
    city { 'Kyiv' }
    start_at { 1.week.from_now }
    end_at { 1.week.from_now + 2.hours }

    trait :draft do
      status { 'draft' }
    end

    trait :published do
      status { 'published' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    trait :online do
      location_type { 'online' }
      address { nil }
      online_url { 'https://example.com/stream' }
    end

    trait :past do
      start_at { 1.week.ago }
      end_at { 1.week.ago + 2.hours }
    end
  end
end
