# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order, type: :model do
  subject(:order) { build(:order, status: 'pending') }

  describe 'associations' do
    it 'belongs to user and event and has many order_items' do
      expect(described_class.reflect_on_association(:user)&.macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:event)&.macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:order_items)&.macro).to eq(:has_many)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(order).to be_valid
    end

    it 'requires total_amount to be present and non-negative' do
      order.total_amount = nil
      expect(order).not_to be_valid

      order.total_amount = -1
      expect(order).not_to be_valid
    end

    it 'requires idempotency_key to be present and unique' do
      order.idempotency_key = nil
      expect(order).not_to be_valid

      create(:order, status: 'pending', idempotency_key: 'idem-key-123')
      order.idempotency_key = 'idem-key-123'
      expect(order).not_to be_valid
    end
  end

  describe 'statuses' do
    it 'defines expected status enum values' do
      expect(described_class.statuses).to eq(
        'pending' => 'pending',
        'paid' => 'paid',
        'cancelled' => 'cancelled'
      )
    end
  end
end
