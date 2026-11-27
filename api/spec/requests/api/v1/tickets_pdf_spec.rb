# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Tickets PDF', type: :request do
  let(:ticket) { create(:ticket) }
  let(:user) { ticket.user }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.encode(user)}" } }

  before { create(:event_translation, event: ticket.event) }

  it 'returns pdf attachment for owner' do
    get "/api/v1/tickets/#{ticket.id}/pdf", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/pdf')
    expect(response.body.byteslice(0, 5)).to eq('%PDF-')
    expect(response.headers['Content-Disposition']).to include("ticket-#{ticket.code}.pdf")
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'rejects anonymous' do
    get "/api/v1/tickets/#{ticket.id}/pdf"
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects non-owner' do
    other = create(:user)
    get "/api/v1/tickets/#{ticket.id}/pdf", headers: { 'Authorization' => "Bearer #{JwtService.encode(other)}" }
    expect(response).to have_http_status(:forbidden)
  end

  it 'returns 404 for missing ticket' do
    get '/api/v1/tickets/999999/pdf', headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'logs the ticket download' do
    expect {
      get "/api/v1/tickets/#{ticket.id}/pdf", headers: headers
    }.to have_enqueued_job(ActivityLogJob).with(
      hash_including(
        'action' => 'ticket.download',
        'entity_type' => 'Ticket',
        'entity_id' => ticket.id.to_s,
        'result' => 'success',
        'user_id' => user.id
      )
    )
  end
end
