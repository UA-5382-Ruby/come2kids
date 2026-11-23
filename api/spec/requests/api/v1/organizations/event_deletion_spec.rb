# frozen_string_literal: true

require 'swagger_helper'

# rswag keeps every documented response in one example group and requires `Authorization`.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
RSpec.describe 'Api::V1::Organizations::Events destroy', type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:organization_id) { organization.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" }
  let(:event) { create(:event, :draft, organization: organization, created_by: owner) }
  let(:id) { event.id }
  let(:issued_count) { 0 }

  before { allow(Events::IssuedTickets).to receive(:for).and_return(issued_count) }

  path '/api/v1/organizations/{organization_id}/events/{id}' do
    delete 'Delete or cancel an event' do
      tags 'Organization events'
      description 'Hides an event that has no issued tickets. ' \
                  'A published event with issued tickets becomes cancelled_by_organizer and is not refunded.'
      security [ bearerAuth: [] ]
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :id, in: :path, schema: { type: :integer }

      response '204', 'event hidden because it has no issued tickets' do
        run_test! do
          expect(event.reload.deleted_at).to be_present
          expect(event.status).to eq('draft')
          expect(enqueued_jobs.map { |job| job[:job] }).not_to include(Events::CancellationNoticeJob)
        end
      end

      response '204', 'published event cancelled because tickets were issued' do
        let(:event) { create(:event, organization: organization, created_by: owner, status: 'published') }
        let(:issued_count) { 1 }

        run_test! do
          expect(event.reload.status).to eq('cancelled_by_organizer')
          expect(event.deleted_at).to be_nil
          expect(event.event_status_histories.map(&:to_status)).to include('cancelled_by_organizer')
          expect(enqueued_jobs.map { |job| job[:job] }).to include(Events::CancellationNoticeJob)
        end
      end

      response '422', 'issued tickets but the event is not published' do
        schema '$ref' => '#/components/schemas/error'
        let(:issued_count) { 1 }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body['code']).to eq('VALIDATION_ERROR')
          expect(body['details'].map { |detail| detail['field'] }).to include('status')
          expect(event.reload.deleted_at).to be_nil
        end
      end

      response '403', 'caller cannot delete this event' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" }

        run_test!
      end

      response '401', 'missing or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { 'Bearer invalid' }

        run_test!
      end

      response '404', 'event was already deleted' do
        schema '$ref' => '#/components/schemas/error'
        let(:event) { create(:event, :draft, organization: organization, created_by: owner, deleted_at: Time.current) }

        run_test!
      end
    end
  end

  describe 'blocked organization' do
    it 'rejects the delete' do
      organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'spam')

      delete "/api/v1/organizations/#{organization.id}/events/#{event.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VariableName, RSpec/EmptyExampleGroup
