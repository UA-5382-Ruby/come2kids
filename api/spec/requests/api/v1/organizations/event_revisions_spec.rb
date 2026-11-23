# frozen_string_literal: true

require 'swagger_helper'

# rswag keeps every documented response in one example group and requires `Authorization`.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
RSpec.describe 'Api::V1::Organizations::Event revisions', type: :request do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:organization_id) { organization.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" }
  let(:event) do
    create(:event, organization: organization, created_by: owner, status: 'published',
      location_type: 'offline', address: 'вул. Хрещатик, 1', city: 'Київ').tap do |created|
      create(:event_translation, event: created, locale: 'uk', title: 'Майстерня')
      create(:ticket_type, event: created)
    end
  end
  let(:id) { event.id }
  let(:event_id) { event.id }

  path '/api/v1/organizations/{organization_id}/events/{id}' do
    put 'Edit a published event through a revision' do
      tags 'Organization events'
      description 'A published event keeps its public row. The request creates or updates one pending revision.'
      security [ bearerAuth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :id, in: :path, schema: { type: :integer }
      parameter name: :payload, in: :body, schema: { '$ref' => '#/components/schemas/draftEventRequest' }

      response '200', 'pending revision saved' do
        schema '$ref' => '#/components/schemas/eventRevisionResponse'
        let(:payload) { { event: { city: 'Львів' } } }

        run_test! do |response|
          body = JSON.parse(response.body).fetch('data')

          expect(body['status']).to eq('under_review')
          expect(body.dig('payload', 'city')).to eq('Львів')
          expect(event.reload.city).to eq('Київ')
        end
      end

      response '403', 'caller cannot revise this event' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" }
        let(:payload) { { event: { city: 'Львів' } } }

        run_test!
      end

      response '401', 'missing or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { 'Bearer invalid' }
        let(:payload) { { event: { city: 'Львів' } } }

        run_test!
      end
    end
  end

  path '/api/v1/organizations/{organization_id}/events/{event_id}/revision' do
    delete 'Withdraw a pending revision' do
      tags 'Organization events'
      security [ bearerAuth: [] ]
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :event_id, in: :path, schema: { type: :integer }

      response '204', 'revision withdrawn' do
        before do
          Events::Revisions::Upsert.call(event: event, actor: owner, attributes: { city: 'Львів' })
        end

        run_test! do
          expect(event.reload.pending_revision).to be_nil
          expect(event.event_revisions.last.status).to eq('withdrawn')
        end
      end

      response '404', 'no pending revision' do
        run_test!
      end

      response '403', 'caller cannot withdraw a revision' do
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" }

        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
