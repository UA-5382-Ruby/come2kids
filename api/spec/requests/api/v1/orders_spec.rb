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

    context 'when request is valid' do
      it 'creates an order and reserves tickets' do
        post "/api/v1/events/#{published_event.id}/orders",
             params: { ticket_type_id: ticket_type.id, quantity: 2 },
             headers: headers

        expect(response).to have_http_status(:created)
        expect(response.parsed_body.fetch('data')).to include('amountMinor' => 600, 'status' => 'pending')
        expect(response.parsed_body.fetch('data')).not_to have_key('idempotency_key')
        expect(response.parsed_body.fetch('data')).not_to have_key('total_amount')
        expect(Order.count).to eq(1)
        expect(ticket_type.reload.sold_quantity).to eq(3)
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
end
