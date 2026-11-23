# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Appeals', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:blocked_user) { create(:user, :blocked, blocked_at: 1.day.ago) }
  let(:authorization) { "Bearer #{JwtService.encode_appeal(blocked_user)}" }

  describe 'the appeal token' do
    it 'is returned at login together with USER_BLOCKED' do
      Rails.cache.clear
      post '/api/v1/auth/login', params: { email: blocked_user.email, password: 'Password123' }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json).to include('code' => 'USER_BLOCKED', 'appeal_token_expires_in' => JwtService::APPEAL_TTL.to_i)
      expect(JwtService.decode(json['appeal_token'])).to include('sub' => blocked_user.id.to_s, 'scope' => 'appeal')
      expect(json).not_to have_key('access_token')
    end

    it 'does not open any other endpoint' do
      get '/api/v1/users/me', headers: { 'Authorization' => authorization }

      expect(response).to have_http_status(:forbidden)
      expect(json['code']).to eq('APPEAL_TOKEN_SCOPE')
    end
  end

  describe '/api/v1/appeals' do
    path '/api/v1/appeals' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization,
                description: 'Appeal token of a blocked user, or the access token of an organization owner'

      post 'Submit an appeal against a block' do
        tags 'Appeals'
        description 'A blocked user uses the appeal token returned by the login endpoint. The owner of a blocked ' \
                    'organization uses a normal access token and passes organization_id; managers cannot appeal. ' \
                    'One open appeal per block; after a rejection a new appeal is accepted 24 hours later.'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :appeal, in: :body, schema: {
          type: :object,
          properties: {
            message: { type: :string, maxLength: Appeal::MESSAGE_MAX_LENGTH },
            organization_id: { type: :integer, description: 'Only for an appeal of a blocked organization' }
          },
          required: %w[message]
        }

        let(:appeal) { { message: 'I did not send spam.' } }

        response '201', 'appeal submitted' do
          schema type: :object, properties: { data: { '$ref' => '#/components/schemas/appeal' } }, required: %w[data]

          context 'with the appeal token of a blocked user' do
            run_test! do
              expect(json['data']).to include('target_type' => 'User', 'target_id' => blocked_user.id,
                                              'status' => 'open')
              expect(ModerationLog.find_by(entity_type: 'Appeal', entity_id: json['data']['id']).decision)
                .to eq('appeal_submitted')
            end
          end

          context 'when a rejection concerned an earlier block' do
            before do
              create(:appeal, :rejected, target: blocked_user, reviewed_at: 2.hours.ago)
              blocked_user.update!(blocked_at: 1.hour.ago)
            end

            run_test!
          end

          context 'with the owner of a blocked organization' do
            let(:organization) { create(:organization, :blocked) }
            let(:authorization) do
              "Bearer #{JwtService.encode(create(:company_member, :owner, organization: organization).user)}"
            end
            let(:appeal) { { message: 'We fixed it.', organization_id: organization.id } }

            run_test! do
              expect(json['data']).to include('target_type' => 'Organization', 'target_id' => organization.id)
            end
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'access token of a blocked user, or a manager' do
          schema '$ref' => '#/components/schemas/error'

          context 'with an access token of the blocked user instead of the appeal token' do
            let(:authorization) { "Bearer #{JwtService.encode(blocked_user)}" }

            run_test! { expect(json['code']).to eq('USER_BLOCKED') }
          end

          context 'with a manager of the blocked organization' do
            let(:organization) { create(:organization, :blocked) }
            let(:authorization) do
              "Bearer #{JwtService.encode(create(:company_member, :manager, organization: organization).user)}"
            end
            let(:appeal) { { message: 'Please', organization_id: organization.id } }

            run_test! { expect(json['code']).to eq('FORBIDDEN') }
          end

          context 'with the owner of another organization' do
            let(:organization) { create(:organization, :blocked) }
            let(:authorization) { "Bearer #{JwtService.encode(create(:company_member, :owner).user)}" }
            let(:appeal) { { message: 'Not mine', organization_id: organization.id } }

            run_test! do
              expect(json['code']).to eq('FORBIDDEN')
              expect(Appeal.for_target(organization)).to be_empty
            end
          end
        end

        response '409', 'not blocked, or an appeal is already open' do
          schema '$ref' => '#/components/schemas/error'

          context 'with an open appeal' do
            before { create(:appeal, target: blocked_user) }

            run_test! { expect(json['code']).to eq('APPEAL_ALREADY_OPEN') }
          end

          context 'when the user has been unblocked meanwhile' do
            before { blocked_user.update!(blocked_at: nil, block_reason: nil) }

            run_test! { expect(json['code']).to eq('NOT_BLOCKED') }
          end

          context 'with an organization that is not blocked' do
            let(:organization) { create(:organization) }
            let(:authorization) do
              "Bearer #{JwtService.encode(create(:company_member, :owner, organization: organization).user)}"
            end
            let(:appeal) { { message: 'Hi', organization_id: organization.id } }

            run_test! { expect(json['code']).to eq('NOT_BLOCKED') }
          end
        end

        response '422', 'message missing or too long' do
          schema '$ref' => '#/components/schemas/error'

          let(:appeal) { { message: 'a' * 2001 } }

          run_test! { expect(json['details'].first['field']).to eq('message') }
        end

        response '429', 'rejected less than 24 hours ago' do
          schema '$ref' => '#/components/schemas/error'

          let!(:rejected) { create(:appeal, :rejected, target: blocked_user, reviewed_at: 2.hours.ago) }

          context 'when the cooldown has not passed' do
            run_test!('says when a new appeal is allowed') do
              allowed_at = (rejected.reviewed_at + 24.hours).utc.iso8601
              expect(json['code']).to eq('APPEAL_COOLDOWN')
              expect(json['details'].first).to eq('field' => 'next_appeal_allowed_at', 'message' => allowed_at)
            end
          end

          it 'accepts the appeal once the cooldown has passed' do
            travel 23.hours do
              post '/api/v1/appeals', params: appeal, headers: { 'Authorization' => authorization }, as: :json
              expect(response).to have_http_status(:created)
            end
          end
        end
      end
    end
  end

  describe '/api/v1/appeals/current' do
    path '/api/v1/appeals/current' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization

      get 'Appeal status, decision and when a new appeal is allowed' do
        tags 'Appeals'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :organization_id, in: :query, type: :integer, required: false

        response '401', 'not authenticated' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { nil }

          run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
        end

        response '403', 'the organization belongs to someone else' do
          schema '$ref' => '#/components/schemas/error'

          let(:organization_id) { create(:organization, :blocked).id }
          let(:authorization) { "Bearer #{JwtService.encode(create(:company_member, :owner).user)}" }

          run_test! do
            expect(json['code']).to eq('FORBIDDEN')
            expect(json).not_to have_key('data')
          end
        end

        response '200', 'current state' do
          schema type: :object,
                 properties: {
                   data: {
                     type: :object,
                     properties: {
                       target_type: { type: :string },
                       target_id: { type: :integer },
                       blocked: { type: :boolean },
                       block_reason: { type: :string, nullable: true },
                       appeal: { allOf: [ { '$ref' => '#/components/schemas/appeal' } ], nullable: true },
                       can_submit: { type: :boolean },
                       next_appeal_allowed_at: { type: :string, format: 'date-time', nullable: true }
                     },
                     required: %w[target_type target_id blocked can_submit]
                   }
                 },
                 required: %w[data]

          context 'with a recent rejection' do
            before { create(:appeal, :rejected, target: blocked_user, reviewed_at: 1.hour.ago) }

            run_test! do
              expect(json['data']).to include('blocked' => true, 'block_reason' => 'Spam', 'can_submit' => false)
              expect(json['data']['appeal']).to include('status' => 'rejected', 'decision_reason' => 'The block stays.')
              expect(json['data']['next_appeal_allowed_at']).to be_present
            end
          end

          context 'without any appeal' do
            run_test! do
              expect(json['data']).to include('appeal' => nil, 'can_submit' => true, 'next_appeal_allowed_at' => nil)
            end
          end
        end
      end
    end
  end
end
