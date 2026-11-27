# frozen_string_literal: true

FactoryBot.define do
  factory :answer do
    association :question
    association :author, factory: :user
    text { 'Yes, free parking is available right next to the entrance.' }
  end
end
