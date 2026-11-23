# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderCreationService, type: :service do
  let(:user) { create(:user) }
  let(:event) { create(:event, :published) }
  let(:ticket_type) do
    create(:ticket_type, event: event, price: 250, currency: 'UAH', total_quantity: 10, sold_quantity: 2)
  end

  def call_service(quantity: 2, idempotency_key: 'order-idem-001', target_event: event, target_ticket: ticket_type)
    described_class.new(
      user: user,
      event: target_event,
      ticket_type_id: target_ticket.id,
      quantity: quantity,
      idempotency_key: idempotency_key
    ).call
  end

  describe '#call' do
    [ nil, 0, -1, 1.5, '1.5', '2tickets', [], [ '2' ], {}, '' ].each do |quantity|
      it "rejects malformed quantity #{quantity.inspect}" do
        expect { call_service(quantity: quantity) }.to raise_error(described_class::InvalidQuantityError)
      end
    end

    it 'accepts a positive integer string' do
      expect(call_service(quantity: '2').order_items.first.quantity).to eq(2)
    end

    it 'rejects a ticket type belonging to another event' do
      other_ticket = create(:ticket_type)
      expect { call_service(target_ticket: other_ticket) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(other_ticket.reload.sold_quantity).to eq(0)
    end

    it 'rejects a globally unique key belonging to another user' do
      existing = create(:order, idempotency_key: 'other-user')
      expect { call_service(idempotency_key: existing.idempotency_key) }
        .to raise_error(described_class::IdempotencyConflictError)
      expect(ticket_type.reload.sold_quantity).to eq(2)
    end

    it 'replays an order even if its event is no longer published' do
      existing = create(:order, user: user, event: event, idempotency_key: 'replay')
      event.update!(status: 'draft')
      expect(call_service(idempotency_key: 'replay')).to eq(existing)
    end

    it 'rechecks the key after acquiring the transaction lock before checking inventory' do
      existing = create(:order, user: user, event: event, idempotency_key: 'racing-key')
      allow(Order).to receive(:find_by).with(idempotency_key: 'racing-key').and_return(nil, existing)
      ticket_type.update!(sold_quantity: ticket_type.total_quantity)
      expect(call_service(idempotency_key: 'racing-key')).to eq(existing)
    end

    context 'with valid paid ticket reservation' do
      it 'creates a pending order with 15-minute reservation and no tickets' do
        expect { call_service }
          .to change(Order, :count).by(1)
          .and change(OrderItem, :count).by(1)
          .and change { ticket_type.reload.sold_quantity }.by(2)

        order = Order.last
        expect(order).to be_pending
        expect(order.total_amount).to eq(500)
        expect(order.currency).to eq('UAH')
        expect(order.reserved_until).to be_within(5.seconds).of(15.minutes.from_now)
        expect(order.tickets).to be_empty
      end
    end

    context 'with free tickets (price = 0)' do
      let(:free_ticket) do
        create(:ticket_type, event: event, price: 0, total_quantity: 10, sold_quantity: 0)
      end

      it 'creates a paid order without reserved_until' do
        order = call_service(quantity: 3, target_ticket: free_ticket)

        expect(order).to be_paid
        expect(order.total_amount).to eq(0)
        expect(order.reserved_until).to be_nil
      end

      it 'issues unique valid tickets immediately' do
        order = nil

        expect { order = call_service(quantity: 3, target_ticket: free_ticket) }
          .to change(Ticket, :count).by(3)

        tickets = order.tickets
        expect(tickets).to all(be_status_valid)
        expect(tickets.map(&:user_id)).to all(eq(user.id))
        expect(tickets.map(&:event_id)).to all(eq(event.id))
        expect(tickets.map(&:code).uniq.size).to eq(3)
        expect(tickets.map(&:qr_token).uniq.size).to eq(3)
      end

      it 'does not issue duplicate tickets on idempotency replay' do
        first_order = call_service(quantity: 2, idempotency_key: 'free-idem-001', target_ticket: free_ticket)

        expect do
          replayed = call_service(quantity: 2, idempotency_key: 'free-idem-001', target_ticket: free_ticket)
          expect(replayed).to eq(first_order)
        end.not_to change(Ticket, :count)
      end
    end

    context 'when idempotency_key was already used' do
      it 'returns existing order without creating a duplicate' do
        existing = create(:order, user: user, event: event, status: 'pending', idempotency_key: 'dup-key')

        expect { call_service(idempotency_key: 'dup-key') }.not_to change(Order, :count)
        expect(call_service(idempotency_key: 'dup-key')).to eq(existing)
      end
    end

    context 'when event is not published' do
      it 'raises EventNotPublishedError' do
        draft_event = create(:event, :draft)

        expect { call_service(target_event: draft_event) }
          .to raise_error(described_class::EventNotPublishedError)
      end
    end

    context 'when quantity is zero or negative' do
      it 'raises InvalidQuantityError' do
        expect { call_service(quantity: 0) }.to raise_error(described_class::InvalidQuantityError)
      end
    end

    context 'when requested quantity exceeds available tickets' do
      it 'raises TicketsSoldOutError without mutating sold_quantity' do
        expect { call_service(quantity: 9) }.to raise_error(described_class::TicketsSoldOutError)
        expect(ticket_type.reload.sold_quantity).to eq(2)
      end
    end
  end
end
