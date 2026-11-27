# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Tickets PDF', type: :request do
  let(:ticket) { create(:ticket) }
  let(:user) { ticket.user }
  let(:authorization) { "Bearer #{JwtService.encode(user)}" }

  before { create(:event_translation, event: ticket.event) }

  it 'returns pdf for owner' do
    get "/api/v1/tickets/#{ticket.id}/pdf", headers: { 'Authorization' => authorization }
    expect(response).to have_http_status(:ok)
  end

  path '/api/v1/tickets/{id}/pdf' do
    get 'Download PDF ticket' do
      tags 'Tickets'
      produces 'application/pdf'
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :authorization, in: :header, type: :string, required: true

      response '200', 'PDF file' do
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
