# frozen_string_literal: true

require 'swagger_helper'

# rswag keeps documented responses in one example group and requires `Authorization`.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
RSpec.describe 'Api::V1::Organizations::Events::Tickets', type: :request do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:event) { create(:event, organization: organization, created_by: owner, status: 'published') }
  let(:organization_id) { organization.id }
  let(:event_id) { event.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" }

  path '/api/v1/organizations/{organization_id}/events/{event_id}/tickets' do
    get 'List issued tickets' do
      tags 'Organization events'
      description 'Lists issued tickets for an organizer. Returns an empty page until tickets exist.'
      security [ bearerAuth: [] ]
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :event_id, in: :path, schema: { type: :integer }
      parameter name: :q, in: :query, required: false, schema: { type: :string }
      parameter name: :page, in: :query, required: false, schema: { type: :integer }
      parameter name: :pageSize, in: :query, required: false, schema: { type: :integer }

      response '200', 'empty participant page' do
        schema '$ref' => '#/components/schemas/participantPage'
        let(:q) { 'Майстерня' }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body.fetch('data')).to eq([])
          expect(body.dig('pagination', 'totalCount')).to eq(0)
        end
      end

      response '403', 'caller is not a member' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" }

        run_test!
      end

      response '401', 'missing or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { 'Bearer invalid' }

        run_test!
      end

      response '404', 'event not found' do
        schema '$ref' => '#/components/schemas/error'
        let(:event_id) { 0 }

        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
