# frozen_string_literal: true

FactoryBot.define do
  factory :event_revision do
    association :event
    association :submitted_by, factory: :user
    status { 'under_review' }
    payload { { 'time_zone' => 'Europe/Kyiv' } }
  end
end
