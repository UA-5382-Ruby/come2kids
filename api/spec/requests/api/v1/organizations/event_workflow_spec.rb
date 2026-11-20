# frozen_string_literal: true

require 'swagger_helper'

# rswag keeps every documented response in one example group and requires `Authorization`.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VariableName
RSpec.describe 'Api::V1::Organizations::Events workflow', type: :request do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:organization_id) { organization.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" }
  let(:id) { event.id }
  let(:event) { prepare_draft }

  path '/api/v1/organizations/{organization_id}/events/{id}' do
    put 'Update a draft or rejected event' do
      tags 'Organization events'
      description 'Replaces editable fields while the event is draft or rejected. ' \
                  'Status, author, currency and sold quantity stay under server control.'
      security [ bearerAuth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :id, in: :path, schema: { type: :integer }
      parameter name: :payload, in: :body, schema: { '$ref' => '#/components/schemas/draftEventRequest' }

      response '200', 'event updated' do
        schema '$ref' => '#/components/schemas/managedEventResponse'
        let(:payload) do
          { event: { translations: [ { locale: 'uk', title: 'Нова назва' } ] } }
        end

        run_test! do |response|
          body = JSON.parse(response.body).fetch('data')

          expect(body['status']).to eq('draft')
          expect(body['event_translations']).to contain_exactly(
            a_hash_including('locale' => 'uk', 'title' => 'Нова назва')
          )
        end
      end

      response '403', 'event cannot be edited' do
        schema '$ref' => '#/components/schemas/error'
        let(:event) { prepare_draft(status: 'under_review') }
        let(:payload) { { event: { city: 'Львів' } } }

        run_test!
      end

      response '401', 'missing or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { 'Bearer invalid' }
        let(:payload) { { event: {} } }

        run_test!
      end

      response '404', 'event not found' do
        schema '$ref' => '#/components/schemas/error'
        let(:id) { 0 }
        let(:payload) { { event: {} } }

        run_test!
      end
    end
  end

  path '/api/v1/organizations/{organization_id}/events/{id}/submit' do
    post 'Submit an event for moderation' do
      tags 'Organization events'
      description 'Moves a complete draft or rejected event to under_review. ' \
                  'An incomplete event stays unchanged and returns field errors.'
      security [ bearerAuth: [] ]
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :id, in: :path, schema: { type: :integer }

      response '200', 'event submitted' do
        schema '$ref' => '#/components/schemas/managedEventResponse'

        run_test! do |response|
          body = JSON.parse(response.body).fetch('data')

          expect(body['status']).to eq('under_review')
          expect(event.reload.submitted_at).to be_present
          expect(event.event_status_histories.map(&:to_status)).to eq([ 'under_review' ])
        end
      end

      response '422', 'event is incomplete' do
        schema '$ref' => '#/components/schemas/error'
        let(:event) { prepare_draft(address: nil) }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body['code']).to eq('VALIDATION_ERROR')
          expect(body['details'].map { |detail| detail['field'] }).to include('address')
          expect(event.reload.status).to eq('draft')
          expect(event.event_status_histories).to be_empty
        end
      end

      response '403', 'caller cannot submit this event' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" }

        run_test!
      end

      response '401', 'missing or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { 'Bearer invalid' }

        run_test!
      end
    end
  end

  describe 'workflow rules' do
    it 'lets an owner edit and submit a rejected event' do
      rejected = prepare_draft(status: 'rejected')

      put "/api/v1/organizations/#{organization.id}/events/#{rejected.id}",
          params: { event: { city: 'Львів' } }, headers: auth_headers(owner), as: :json
      expect(response).to have_http_status(:ok)

      post "/api/v1/organizations/#{organization.id}/events/#{rejected.id}/submit",
           headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:ok)
      expect(rejected.reload.status).to eq('under_review')
    end

    it 'rejects submit when the status cannot move to review' do
      published = prepare_draft(status: 'published')

      post "/api/v1/organizations/#{organization.id}/events/#{published.id}/submit",
           headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body['details'].map { |detail| detail['field'] }).to include('status')
      expect(published.reload.status).to eq('published')
    end

    it 'rejects a blocked organization' do
      organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'spam')

      post "/api/v1/organizations/#{organization.id}/events/#{event.id}/submit",
           headers: auth_headers(owner), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  def prepare_draft(**overrides)
    create(:event, :draft, { organization: organization, created_by: owner, address: 'вул. Хрещатик, 1' }.merge(overrides))
      .tap do |created|
        create(:event_translation, event: created, locale: 'uk', title: 'Майстерня')
        create(:ticket_type, event: created)
      end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VariableName
