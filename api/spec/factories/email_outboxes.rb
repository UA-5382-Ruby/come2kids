# frozen_string_literal: true

FactoryBot.define do
  factory :email_outbox do
    to_email { 'buyer@example.com' }
    template { 'ticket_purchase' }
    sequence(:dedup_key) { |n| "ticket_purchase:#{n}" }
    payload { {} }
    status { 'pending' }
  end
end
