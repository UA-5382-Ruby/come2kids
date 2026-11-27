# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Organizations::Events::CheckInStatistics', type: :request do
  let(:ticket) { create(:ticket) }
  let(:event) { ticket.event }
  let(:scanner) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.encode(scanner)}" } }
  let(:url) { "/api/v1/organizations/#{event.organization_id}/events/#{event.id}/check_in_statistics" }

  before do
    create(:company_member, :owner, organization: event.organization, user: scanner)
  end

  it 'returns attendance statistics for a member' do
    ticket.update_columns(status: 'used', used_at: Time.current)
    get url, headers: headers
    expect(response).to have_http_status(:ok)
    data = response.parsed_body['data'] || response.parsed_body
    expect(data['issued']).to eq(1)
    expect(data['checked_in']).to eq(1)
    expect(data['attendance_rate']).to eq(100.0)
  end

  it 'rejects anonymous' do
    get url
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a non-member' do
    outsider = create(:user)
    get url, headers: { 'Authorization' => "Bearer #{JwtService.encode(outsider)}" }
    expect(response).to have_http_status(:forbidden)
  end
end
