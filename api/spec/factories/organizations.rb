# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    sequence(:slug) { |n| "organization-#{n}" }
    sequence(:contact_email) { |n| "organization#{n}@example.com" }
    status { "approved" }
    approved_at { Time.current }
  end
end
