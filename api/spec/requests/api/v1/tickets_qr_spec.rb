# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Tickets QR', type: :request do
  let(:ticket) { create(:ticket) }
  let(:user) { ticket.user }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.encode(user)}" } }

  it 'returns png for owner' do
    get "/api/v1/tickets/#{ticket.id}/qr", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('image/png')
    expect(response.body.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
  end

  it 'returns svg when requested' do
    get "/api/v1/tickets/#{ticket.id}/qr", params: { format: 'svg' }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('image/svg+xml')
  end

  it 'rejects unsupported format' do
    get "/api/v1/tickets/#{ticket.id}/qr", params: { format: 'gif' }, headers: headers
    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects anonymous' do
    get "/api/v1/tickets/#{ticket.id}/qr"
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects non-owner' do
    other = create(:user)
    get "/api/v1/tickets/#{ticket.id}/qr", headers: { 'Authorization' => "Bearer #{JwtService.encode(other)}" }
    expect(response).to have_http_status(:forbidden)
  end

  it 'returns 404 for missing ticket' do
    get '/api/v1/tickets/999999/qr', headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
