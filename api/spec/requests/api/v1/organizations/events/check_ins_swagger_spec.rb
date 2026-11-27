# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Organizations::Events::CheckIns', type: :request do
  let(:ticket) { create(:ticket) }
  let(:authorization) { "Bearer #{JwtService.encode(scanner)}" }
  let(:organization_id) { ticket.event.organization_id }
  let(:event_id) { ticket.event_id }
  let(:payload) { { qr_token: ticket.qr_token } }

  before do
    create(:company_member, :owner, organization: ticket.event.organization, user: scanner)
  end

  def scanner
    @scanner ||= create(:user)
  end

  path '/api/v1/organizations/{organization_id}/events/{event_id}/check_ins' do
    post 'Check in a ticket by QR token' do
      tags 'Organization events'
      consumes 'application/json'
      produces 'application/json'
      description 'Marks a ticket as used. Only organization members may scan; the transition is atomic.'

      parameter name: :organization_id, in: :path, type: :integer, required: true
      parameter name: :event_id, in: :path, type: :integer, required: true
      parameter name: :authorization, in: :header, type: :string, required: true
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: { qr_token: { type: :string } },
        required: %w[qr_token]
      }

      response '200', 'ticket checked in' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:authorization) { nil }
        run_test!
      end

      response '403', 'caller is not a member' do
        let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }
        run_test!
      end

      response '404', 'unknown token or ticket of another event' do
        let(:payload) { { qr_token: 'unknown-token' } }
        run_test!
      end

      response '409', 'ticket already used' do
        let(:payload) { { qr_token: create(:ticket, event: ticket.event, status: 'used').qr_token } }
        run_test!
      end
    end
  end
end
