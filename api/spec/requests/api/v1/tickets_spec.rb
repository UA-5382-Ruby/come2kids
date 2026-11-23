# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Tickets', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:event) { create(:event, :published) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{JwtService.encode(user)}" } }

  describe 'GET /api/v1/tickets/my' do
    let(:other_event) { create(:event, :published) }

    it 'returns 401 Unauthorized without token' do
      get '/api/v1/tickets/my'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only current user tickets with pagination' do
      my_ticket = create(:ticket, user: user, event: event, status: 'valid')
      my_used = create(:ticket, user: user, event: other_event, status: 'used')
      create(:ticket, user: other_user, event: event, status: 'valid')

      get '/api/v1/tickets/my', headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('data').map { |item| item['id'] }
      expect(ids).to contain_exactly(my_ticket.id, my_used.id)
      expect(response.parsed_body.fetch('pagination')).to include('totalCount' => 2, 'page' => 1)
    end

    it 'filters tickets by status and event_id' do
      matching = create(:ticket, user: user, event: event, status: 'valid')
      create(:ticket, user: user, event: event, status: 'used')
      create(:ticket, user: user, event: other_event, status: 'valid')

      get '/api/v1/tickets/my', params: { status: 'valid', event_id: event.id }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('data').map { |item| item['id'] }
      expect(ids).to eq([ matching.id ])
    end
  end

  describe 'GET /api/v1/tickets/:id' do
    let(:ticket) { create(:ticket, user: user, event: event, status: 'valid') }

    it 'returns 401 Unauthorized without token' do
      get "/api/v1/tickets/#{ticket.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns ticket details with qr_token for the owner' do
      get "/api/v1/tickets/#{ticket.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body.fetch('data')
      expect(data).to include(
        'id' => ticket.id,
        'event_id' => event.id,
        'code' => ticket.code,
        'qr_token' => ticket.qr_token,
        'status' => 'valid'
      )
    end

    it 'returns 403 Forbidden for another user ticket' do
      other_ticket = create(:ticket, user: other_user, event: event)

      get "/api/v1/tickets/#{other_ticket.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 Not Found for nonexistent ticket' do
      get '/api/v1/tickets/999999', headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['code']).to eq('NOT_FOUND')
    end
  end
end
