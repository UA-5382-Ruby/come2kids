# frozen_string_literal: true

FactoryBot.define do
  factory :appeal do
    target factory: %i[user blocked]
    submitted_by { target.is_a?(User) ? target : association(:user) }
    message { 'Please review my block, it was a mistake.' }
    status { 'open' }

    trait :rejected do
      status { 'rejected' }
      reviewed_by factory: %i[user moderator]
      reviewed_at { Time.current }
      decision_reason { 'The block stays.' }
    end
  end
end
