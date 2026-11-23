# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReleaseExpiredReservationsService do
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) { create(:ticket_type, event: event, price: 10_000, total_quantity: 10, sold_quantity: 3) }
  let(:user) { create(:user) }

  describe '.call' do
    it 'expires pending orders past reserved_until and returns tickets to sale' do
      order = create(:order, user: user, event: event, status: :pending, reserved_until: 5.minutes.ago)
      create(:order_item, order: order, ticket_type: ticket_type, quantity: 3, unit_price: 10_000)

      result = described_class.call

      expect(result).to be_success
      expect(result.value!).to eq(1)
      expect(order.reload).to be_expired
      expect(ticket_type.reload.sold_quantity).to eq(0)
    end

    it 'does not touch pending orders whose reservation has not expired yet' do
      order = create(:order, user: user, event: event, status: :pending, reserved_until: 10.minutes.from_now)
      create(:order_item, order: order, ticket_type: ticket_type, quantity: 3, unit_price: 10_000)

      result = described_class.call

      expect(result).to be_success
      expect(result.value!).to eq(0)
      expect(order.reload).to be_pending
      expect(ticket_type.reload.sold_quantity).to eq(3)
    end

    it 'does not touch already paid or cancelled orders' do
      paid_order = create(:order, user: user, event: event, status: :paid, reserved_until: 5.minutes.ago)
      create(:order_item, order: paid_order, ticket_type: ticket_type, quantity: 2, unit_price: 10_000)

      result = described_class.call

      expect(result).to be_success
      expect(result.value!).to eq(0)
      expect(paid_order.reload).to be_paid
      expect(ticket_type.reload.sold_quantity).to eq(3)
    end

    it 'is idempotent when called multiple times' do
      order = create(:order, user: user, event: event, status: :pending, reserved_until: 5.minutes.ago)
      create(:order_item, order: order, ticket_type: ticket_type, quantity: 3, unit_price: 10_000)

      first_result = described_class.call
      second_result = described_class.call

      expect(first_result.value!).to eq(1)
      expect(second_result.value!).to eq(0)
      expect(ticket_type.reload.sold_quantity).to eq(0)
    end
  end
end
