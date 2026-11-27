# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Tickets QR', type: :request do
  let(:ticket) { create(:ticket) }
  let(:user) { ticket.user }
  let(:authorization) { "Bearer #{JwtService.encode(user)}" }

  it 'returns png for owner' do
    get "/api/v1/tickets/#{ticket.id}/qr", headers: { 'Authorization' => authorization }
    expect(response).to have_http_status(:ok)
  end

  path '/api/v1/tickets/{id}/qr' do
    get 'Ticket QR code image' do
      tags 'Tickets'
      produces 'image/png', 'image/svg+xml'
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :format, in: :query, type: :string, required: false
      parameter name: :authorization, in: :header, type: :string, required: true

      response '200', 'QR image' do
        let(:id) { ticket.id }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:id) { ticket.id }
        let(:authorization) { nil }
        run_test!
      end

      response '403', 'forbidden' do
        let(:id) { ticket.id }
        let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }
        run_test!
      end

      response '404', 'not found' do
        let(:id) { 0 }
        run_test!
      end
    end
  end
end
