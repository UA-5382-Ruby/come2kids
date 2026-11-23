# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth: confirm email', type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :unconfirmed) }
  let!(:raw_token) { Tokens::EmailConfirmation.issue(user) }

  path '/api/v1/auth/confirm-email' do
    post 'Confirm the email address with the token from the email' do
      tags 'Auth'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Accept-Language', in: :header, type: :string, required: false, getter: :accept_language
      parameter name: :confirmation, in: :body, schema: {
        type: :object,
        properties: { token: { type: :string, description: 'Single-use token from the email, valid 24 hours' } },
        required: %w[token]
      }

      let(:confirmation) { { token: raw_token } }

      response '200', 'email confirmed' do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 user: { type: :object, properties: { id: { type: :integer }, email_confirmed: { type: :boolean } } }
               },
               required: %w[message user]

        context 'with a valid token' do
          run_test! do
            expect(json['message']).to be_present
            expect(json['user']).to include('id' => user.id, 'email_confirmed' => true)
            expect(user.reload).to be_email_confirmed
            token_key = Tokens::EmailConfirmation.token_key(Tokens::EmailConfirmation.digest(raw_token))
            expect(Tokens::EmailConfirmation.redis.exists?(token_key)).to be(false)
          end
        end

        it 'works right before the token expires' do
          travel_to(23.hours.from_now) { send_documented_request }

          expect(response).to have_http_status(:ok)
        end

        context 'when the email is already confirmed' do
          let(:confirmed_at) { 2.days.ago.change(usec: 0) }

          before { user.update!(email_confirmed_at: confirmed_at) }

          run_test! { expect(user.reload.email_confirmed_at).to eq(confirmed_at) }
        end

        context 'with the newest of two tokens' do
          let(:confirmation) { { token: Tokens::EmailConfirmation.issue(user) } }

          run_test!
        end

        it 'confirms the account with the token from the registration email (full flow)' do
          ActionMailer::Base.deliveries.clear
          perform_enqueued_jobs do
            post '/api/v1/auth/register', as: :json,
                                          params: { email: 'kid@example.com', password: 'Password123',
                                                    first_name: 'Ira', last_name: 'Koval' }
          end
          token = ActionMailer::Base.deliveries.last.text_part.decoded[/token=([\w-]+)/, 1]

          post '/api/v1/auth/confirm-email', params: { token: token }, as: :json

          expect(response).to have_http_status(:ok)
          expect(User.find_by!(email: 'kid@example.com')).to be_email_confirmed
        end
      end

      response '400', 'token missing' do
        schema '$ref' => '#/components/schemas/error'

        context 'without a token' do
          let(:confirmation) { {} }

          run_test! do
            expect(json['code']).to eq('PARAMETER_MISSING')
            expect(json['details']).to include(a_hash_including('field' => 'token'))
          end
        end

        context 'with a blank token' do
          let(:confirmation) { { token: '' } }

          run_test! { expect(json['code']).to eq('PARAMETER_MISSING') }
        end
      end

      response '422', 'token invalid, expired or already used' do
        schema '$ref' => '#/components/schemas/error'

        context 'with an unknown token' do
          let(:confirmation) { { token: 'unknown-token' } }

          context 'without a language (Ukrainian)' do
            run_test! do
              expect(json['code']).to eq('TOKEN_INVALID')
              expect(json['message']).to start_with('Токен недійсний')
              expect(user.reload).not_to be_email_confirmed
            end
          end

          context 'with Accept-Language: en' do
            let(:accept_language) { 'en' }

            run_test! { expect(json['message']).to start_with('The token is invalid') }
          end
        end

        context 'with the digest used as a token' do
          let(:confirmation) { { token: Tokens::EmailConfirmation.digest(raw_token) } }

          run_test! { expect(json['code']).to eq('TOKEN_INVALID') }
        end

        context 'with an expired token' do
          it 'returns TOKEN_INVALID and leaves the account unverified' do
            travel_to(25.hours.from_now) { send_documented_request }

            expect(response).to have_http_status(:unprocessable_content)
            expect(json['code']).to eq('TOKEN_INVALID')
            expect(user.reload).not_to be_email_confirmed
          end
        end

        context 'with a token that was already used' do
          before { post '/api/v1/auth/confirm-email', params: { token: raw_token }, as: :json }

          run_test! { expect(json['code']).to eq('TOKEN_USED') }
        end

        context 'with a token superseded by a newer one' do
          before { Tokens::EmailConfirmation.issue(user) }

          run_test! { expect(json['code']).to eq('TOKEN_INVALID') }
        end
      end
    end
  end
end
