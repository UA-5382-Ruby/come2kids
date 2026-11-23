# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Moderation: users', type: :request do
  let(:moderator) { create(:user, :moderator) }
  let(:user) { create(:user) }
  let(:authorization) { "Bearer #{JwtService.encode(moderator)}" }
  let(:id) { user.id }

  user_response = {
    type: :object, properties: { data: { '$ref' => '#/components/schemas/moderation_user' } }, required: %w[data]
  }

  describe '/api/v1/moderation/users/{id}/block' do
    path '/api/v1/moderation/users/{id}/block' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Block a user (US-6.3, reason required)' do
        tags 'Moderation'
        description 'The access tokens of the user stop working at once. Moderators cannot be blocked.'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body,
                  schema: { type: :object, properties: { reason: { type: :string } }, required: %w[reason] }

        let(:decision) { { reason: 'Spam in questions' } }

        response '200', 'blocked; the user is emailed' do
          schema user_response

          context 'with a regular user' do
            run_test! do
              expect(json['data']).to include('blocked' => true, 'block_reason' => 'Spam in questions')
              expect(user.reload).to have_attributes(blocked_by_id: moderator.id, block_reason: 'Spam in questions')
              expect(ModerationLog.for_entity(user).last)
                .to have_attributes(decision: 'blocked', moderator_id: moderator.id)
            end
          end

          it 'emails the user and writes the activity log' do
            expect { send_documented_request }
              .to have_enqueued_mail(ModerationMailer, :user_block_changed)
              .and have_enqueued_job(ActivityLogJob)
          end

          it 'makes the access tokens of the user stop working at once' do
            user_token = "Bearer #{JwtService.encode(user)}"
            send_documented_request

            get '/api/v1/users/me', headers: { 'Authorization' => user_token }

            expect(response).to have_http_status(:forbidden)
            expect(json['code']).to eq('USER_BLOCKED')
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'not a moderator, or the target is a moderator' do
          schema '$ref' => '#/components/schemas/error'

          context 'when a regular user tries to block' do
            let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

            run_test! { expect(json['code']).to eq('FORBIDDEN') }
          end

          context 'when the target is another moderator' do
            let(:user) { create(:user, :moderator) }

            run_test! do
              expect(json['code']).to eq('CANNOT_BLOCK_MODERATOR')
              expect(user.reload).not_to be_blocked
            end
          end
        end

        response '409', 'already blocked' do
          before { user.update!(blocked_at: Time.current, block_reason: 'Spam') }

          run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
        end

        response '422', 'reason missing' do
          let(:decision) { { reason: ' ' } }

          run_test! { expect(user.reload).not_to be_blocked }
        end
      end
    end
  end

  describe '/api/v1/moderation/users/{id}/unblock' do
    path '/api/v1/moderation/users/{id}/unblock' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Unblock a user' do
        tags 'Moderation'
        description 'Restores access; an open appeal of the user is closed as accepted.'
        produces 'application/json'
        security [ bearerAuth: [] ]

        let(:user) { create(:user, :blocked) }

        response '401', 'not authenticated' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { nil }

          run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
        end

        response '403', 'not a moderator' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

          run_test! { expect(json['code']).to eq('FORBIDDEN') }
        end

        response '200', 'unblocked; the user is emailed' do
          schema user_response

          context 'with a blocked user' do
            run_test!('restores access') do
              expect(user.reload).to have_attributes(blocked_at: nil, block_reason: nil, blocked_by_id: nil)
              get '/api/v1/users/me', headers: { 'Authorization' => "Bearer #{JwtService.encode(user)}" }
              expect(response).to have_http_status(:ok)
            end
          end

          it 'emails the user' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :user_block_changed)
          end

          context 'with an open appeal' do
            let!(:appeal) { create(:appeal, target: user) }

            run_test!('closes it as accepted and logs the decision') do
              expect(appeal.reload).to have_attributes(status: 'accepted', reviewed_by_id: moderator.id)
              expect(ModerationLog.for_entity(appeal).pluck(:decision)).to eq(%w[appeal_accepted])
            end
          end
        end

        response '409', 'not blocked' do
          schema '$ref' => '#/components/schemas/error'

          let(:user) { create(:user) }

          run_test! { expect(json['code']).to eq('NOT_BLOCKED') }
        end
      end
    end
  end
end
