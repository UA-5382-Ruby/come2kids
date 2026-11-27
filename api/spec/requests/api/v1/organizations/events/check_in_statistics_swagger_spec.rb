# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Organizations::Events::CheckInStatistics', type: :request do
  let(:ticket) { create(:ticket) }
  let(:authorization) { "Bearer #{JwtService.encode(scanner)}" }
  let(:organization_id) { ticket.event.organization_id }
  let(:event_id) { ticket.event_id }

  before do
    create(:company_member, :owner, organization: ticket.event.organization, user: scanner)
  end

  def scanner
    @scanner ||= create(:user)
  end

  path '/api/v1/organizations/{organization_id}/events/{event_id}/check_in_statistics' do
    get 'Attendance statistics for an event' do
      tags 'Organization events'
      produces 'application/json'
      description 'Ticket counts and attendance rate for the event. Organization members only.'

      parameter name: :organization_id, in: :path, type: :integer, required: true
      parameter name: :event_id, in: :path, type: :integer, required: true
      parameter name: :authorization, in: :header, type: :string, required: true

      response '200', 'statistics' do
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

      response '404', 'event not found' do
        let(:event_id) { 0 }
        run_test!
      end
    end
  end
end
