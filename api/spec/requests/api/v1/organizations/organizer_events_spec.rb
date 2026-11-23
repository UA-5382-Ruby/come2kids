# frozen_string_literal: true

require 'swagger_helper'

# rswag keeps documented responses in one example group and requires `Authorization`.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
RSpec.describe 'Api::V1::Organizations::Events index', type: :request do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:organization_id) { organization.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" }
  let!(:draft_event) { create(:event, :draft, organization: organization, created_by: owner, city: 'Київ') }
  let!(:hidden_event) { create(:event, :draft, organization: organization, created_by: owner, deleted_at: Time.current) }

  path '/api/v1/organizations/{organization_id}/events' do
    get 'List organization events' do
      tags 'Organization events'
      description 'Lists every status for an owner or manager. Soft-deleted rows stay hidden unless include_deleted=true.'
      security [ bearerAuth: [] ]
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :include_deleted, in: :query, required: false, schema: { type: :boolean }
      parameter name: :status, in: :query, required: false, schema: { type: :string }
      parameter name: :page, in: :query, required: false, schema: { type: :integer }
      parameter name: :pageSize, in: :query, required: false, schema: { type: :integer }

      response '200', 'events listed' do
        run_test! do |response|
          body = JSON.parse(response.body)
          ids = body.fetch('data').map { |event| event['id'] }

          expect(ids).to include(draft_event.id)
          expect(ids).not_to include(hidden_event.id)
          expect(body.dig('pagination', 'totalCount')).to eq(1)
          expect(body.fetch('data').first).to include('pending_revision' => false)
        end
      end

      response '200', 'deleted events included' do
        let(:include_deleted) { true }

        run_test! do |response|
          ids = JSON.parse(response.body).fetch('data').map { |event| event['id'] }

          expect(ids).to include(draft_event.id, hidden_event.id)
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

      response '404', 'organization not found' do
        schema '$ref' => '#/components/schemas/error'
        let(:organization_id) { 0 }

        run_test!
      end
    end
  end

  describe 'organizer list rules' do
    it 'flags a pending revision and allows a blocked organization' do
      create(:event_revision, event: draft_event, submitted_by: owner)
      organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'spam')

      get "/api/v1/organizations/#{organization.id}/events", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      row = response.parsed_body.fetch('data').find { |event| event['id'] == draft_event.id }
      expect(row).to include('pending_revision' => true)
    end

    it 'filters by status' do
      create(:event, organization: organization, created_by: owner, status: 'published', city: 'Львів')

      get "/api/v1/organizations/#{organization.id}/events", params: { status: 'published' }, headers: auth_headers(owner)

      statuses = response.parsed_body.fetch('data').map { |event| event['status'] }
      expect(statuses).to eq([ 'published' ])
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
