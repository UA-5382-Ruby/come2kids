# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Emails::EnqueuePurchase do
  let(:order) { create(:order, status: 'paid') }

  it 'creates an outbox row for the buyer' do
    result = described_class.call(order)
    expect(result).to be_success
    row = EmailOutbox.sole
    expect(row.to_email).to eq(order.user.email)
    expect(row.template).to eq('ticket_purchase')
    expect(row.dedup_key).to eq("ticket_purchase:#{order.id}")
    expect(row.payload).to eq('order_id' => order.id)
  end

  it 'is idempotent on repeated calls' do
    described_class.call(order)
    result = described_class.call(order)
    expect(result).to be_success
    expect(result.value!).to eq(:duplicate)
    expect(EmailOutbox.count).to eq(1)
  end
end
