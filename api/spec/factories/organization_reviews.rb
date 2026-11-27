# frozen_string_literal: true

FactoryBot.define do
  factory :organization_review do
    association :organization
    association :user
    rating { 5 }
    text { 'Excellent organization!' }
  end
end
