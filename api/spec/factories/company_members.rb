# frozen_string_literal: true

FactoryBot.define do
  factory :company_member do
    organization
    user
    role { association :role, :manager }

    trait :owner do
      role { association :role, :owner }
    end

    trait :manager do
      role { association :role, :manager }
    end
  end
end
