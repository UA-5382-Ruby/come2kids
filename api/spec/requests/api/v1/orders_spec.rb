# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Orders', type: :request do
  let(:user) { create(:user) }
  let(:published_event) { create(:event, :published) }
  let(:ticket_type) do
    create(:ticket_type, event: published_event, price: 300, currency: 'UAH', total_quantity: 10, sold_quantity: 1)
  end
  let(:headers) do
    {
      'Authorization' => "Bearer #{JwtService.encode(user)}",
      'Idempotency-Key' => 'req-idem-key-1'
    }
  end

  describe 'POST /api/v1/events/:event_id/orders' do
    context 'when authorization header is missing' do
      it 'returns 401 Unauthorized' do
        post "/api/v1/events/#{published_event.id}/orders", params: { ticket_type_id: ticket_type.id, quantity: 2 }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'rejects a missing idempotency key without invoking the service' do
      allow(OrderCreationService).to receive(:new).and_call_original
      post "/api/v1/events/#{published_event.id}/orders",
           params: { ticket_type_id: ticket_type.id, quantity: 2 },
           headers: headers.except('Idempotency-Key')
      expect(OrderCreationService).not_to have_received(:new)
      expect(response).to have_http_status(:bad_request)
    end

    it 'authorizes before invoking the service' do
      user.update!(email_confirmed_at: nil)
      allow(OrderCreationService).to receive(:new).and_call_original
      post "/api/v1/events/#{published_event.id}/orders",
           params: { ticket_type_id: ticket_type.id, quantity: 2 }, headers: headers
      expect(OrderCreationService).not_to have_received(:new)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 409 for another user’s idempotency key' do
      create(:order, idempotency_key: headers['Idempotency-Key'])
      post "/api/v1/events/#{published_event.id}/orders",
           params: { ticket_type_id: ticket_type.id, quantity: 2 }, headers: headers
      expect(response).to have_http_status(:conflict)
      expect(ticket_type.reload.sold_quantity).to eq(1)
    end

    it 'returns the existing validation response for an array quantity' do
      post "/api/v1/events/#{published_event.id}/orders",
           params: { ticket_type_id: ticket_type.id, quantity: [ '2' ] }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('UNPROCESSABLE_ENTITY')
      expect(Order.count).to eq(0)
    end

    it 'returns 422 for an unpublished event' do
      published_event.update!(status: 'draft')
      post "/api/v1/events/#{published_event.id}/orders",
           params: { ticket_type_id: ticket_type.id, quantity: 2 }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Order.count).to eq(0)
    end

    it 'returns 422 while the organization is blocked (FR-MOD-5)' do
      published_event.organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'Fraud')
      post "/api/v1/events/#{published_event.id}/orders",
           params: { ticket_type_id: ticket_type.id, quantity: 2 }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Ticket sales are closed for this event')
      expect(Order.count).to eq(0)
    end

    context 'when request is valid' do
      it 'creates an order and reserves tickets' do
        post "/api/v1/events/#{published_event.id}/orders",
             params: { ticket_type_id: ticket_type.id, quantity: 2 },
             headers: headers

        expect(response).to have_http_status(:created)
        data = response.parsed_body.fetch('data')
        expect(data).to include('amountMinor' => 600, 'status' => 'pending', 'tickets' => [])
        expect(data).not_to have_key('idempotency_key')
        expect(data).not_to have_key('total_amount')
        expect(Order.count).to eq(1)
        expect(ticket_type.reload.sold_quantity).to eq(3)
      end

      it 'creates a paid order and returns issued tickets for free ticket types' do
        free_ticket = create(:ticket_type, event: published_event, price: 0, currency: 'UAH', total_quantity: 10, sold_quantity: 0)

        post "/api/v1/events/#{published_event.id}/orders",
             params: { ticket_type_id: free_ticket.id, quantity: 2 },
             headers: headers

        expect(response).to have_http_status(:created)
        data = response.parsed_body.fetch('data')
        expect(data).to include('amountMinor' => 0, 'status' => 'paid', 'reserved_until' => nil)

        tickets = data.fetch('tickets')
        expect(tickets.size).to eq(2)
        expect(tickets).to all(include('id' => be_present, 'code' => /\ATKT-[A-Z0-9]{10}\z/, 'qr_token' => be_present, 'status' => 'valid', 'issued_at' => be_present))
        expect(Ticket.count).to eq(2)
        expect(free_ticket.reload.sold_quantity).to eq(2)
      end
    end

    context 'when event does not exist' do
      it 'returns 404 not found' do
        post '/api/v1/events/999999/orders',
             params: { ticket_type_id: ticket_type.id, quantity: 2 },
             headers: headers

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['code']).to eq('NOT_FOUND')
      end
    end

    context 'when tickets are sold out' do
      it 'returns 422 with EVENT_SOLD_OUT code' do
        post "/api/v1/events/#{published_event.id}/orders",
             params: { ticket_type_id: ticket_type.id, quantity: 20 },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['code']).to eq('EVENT_SOLD_OUT')
      end
    end
  end

  describe 'GET /api/v1/orders/my' do
    it 'returns 401 Unauthorized without token' do
      get '/api/v1/orders/my'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only current user orders with pagination' do
      my_paid = create(:order, user: user, event: published_event, status: 'paid')
      my_pending = create(:order, user: user, event: published_event, status: 'pending')
      create(:order, user: create(:user), event: published_event, status: 'paid')

      get '/api/v1/orders/my', headers: headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('data').map { |item| item['id'] }
      expect(ids).to contain_exactly(my_paid.id, my_pending.id)
      expect(response.parsed_body.fetch('pagination')).to include('totalCount' => 2, 'page' => 1)
    end

    it 'filters orders by status' do
      my_paid = create(:order, user: user, event: published_event, status: 'paid')
      create(:order, user: user, event: published_event, status: 'pending')

      get '/api/v1/orders/my', params: { status: 'paid' }, headers: headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('data').map { |item| item['id'] }
      expect(ids).to eq([ my_paid.id ])
    end
  end

  describe 'GET /api/v1/orders/:id' do
    let(:order) { create(:order, user: user, event: published_event, status: 'paid') }

    it 'returns 401 Unauthorized without token' do
      get "/api/v1/orders/#{order.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns order details for the owner' do
      get "/api/v1/orders/#{order.id}", headers: headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body.fetch('data')
      expect(data).to include('id' => order.id, 'event_id' => published_event.id, 'status' => 'paid')
    end

    it 'returns 403 Forbidden for another user order' do
      other_order = create(:order, user: create(:user), event: published_event)

      get "/api/v1/orders/#{other_order.id}", headers: headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 Not Found for nonexistent order' do
      get '/api/v1/orders/999999', headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['code']).to eq('NOT_FOUND')
    end
  end
end
