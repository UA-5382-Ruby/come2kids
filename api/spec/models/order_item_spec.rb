# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  subject(:order_item) { build(:order_item) }

  describe 'associations' do
    it 'belongs to order and ticket_type' do
      expect(described_class.reflect_on_association(:order)&.macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:ticket_type)&.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with the default factory attributes' do
      expect(order_item).to be_valid
    end

    it 'rejects fractional quantities' do
      order_item.quantity = 1.5
      expect(order_item).not_to be_valid
    end

    it 'requires positive integer quantity' do
      order_item.quantity = 0
      expect(order_item).not_to be_valid

      order_item.quantity = -2
      expect(order_item).not_to be_valid
    end

    it 'requires non-negative unit_price' do
      order_item.unit_price = nil
      expect(order_item).not_to be_valid

      order_item.unit_price = -10
      expect(order_item).not_to be_valid
    end
  end
end
