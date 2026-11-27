# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Organizations::Events::CheckIns', type: :request do
  let(:ticket) { create(:ticket) }
  let(:event) { ticket.event }
  let(:scanner) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.encode(scanner)}" } }
  let(:url) { "/api/v1/organizations/#{event.organization_id}/events/#{event.id}/check_ins" }

  before do
    create(:company_member, :owner, organization: event.organization, user: scanner)
  end

  it 'checks in a ticket for an organization member' do
    post url, params: { qr_token: ticket.qr_token }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(ticket.reload.status).to eq('used')
  end

  it 'answers 409 on a repeated scan' do
    post url, params: { qr_token: ticket.qr_token }, headers: headers
    post url, params: { qr_token: ticket.qr_token }, headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it 'answers 404 for an unknown token' do
    post url, params: { qr_token: 'nope' }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects anonymous' do
    post url, params: { qr_token: ticket.qr_token }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a non-member' do
    outsider = create(:user)
    post url, params: { qr_token: ticket.qr_token },
         headers: { 'Authorization' => "Bearer #{JwtService.encode(outsider)}" }
    expect(response).to have_http_status(:forbidden)
  end

  it 'logs the check-in' do
    expect {
      post url, params: { qr_token: ticket.qr_token }, headers: headers
    }.to have_enqueued_job(ActivityLogJob).with(
      hash_including('action' => 'ticket.check_in', 'entity_id' => ticket.id.to_s)
    )
  end
end
