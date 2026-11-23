# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    sequence(:slug) { |n| "organization-#{n}" }
    sequence(:contact_email) { |n| "organization#{n}@example.com" }
    status { "approved" }
    approved_at { Time.current }

    trait :pending do
      status { 'pending_approval' }
      approved_at { nil }
    end

    trait :blocked do
      status { 'blocked' }
      blocked_at { 1.hour.ago }
      block_reason { 'Fraudulent events' }
    end

    # Adds an owner (with a preferred locale) so decisions can be emailed.
    trait :with_owner do
      after(:create) do |organization|
        create(:company_member, :owner, organization: organization)
      end
    end
  end
end
