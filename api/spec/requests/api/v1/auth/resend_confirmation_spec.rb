# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth: resend confirmation', type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  def last_mail_token
    ActionMailer::Base.deliveries.last.text_part.decoded[/token=([\w-]+)/, 1]
  end

  path '/api/v1/auth/resend-confirmation' do
    post 'Send the confirmation email again' do
      tags 'Auth'
      description 'Always answers the same way, so it does not reveal whether an account exists. ' \
                  'A new email is sent at most once per 60 seconds per user.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Accept-Language', in: :header, type: :string, required: false, getter: :accept_language
      parameter name: :resend, in: :body, schema: {
        type: :object, properties: { email: { type: :string, format: :email } }, required: %w[email]
      }

      let(:user) { create(:user, :unconfirmed, email: 'mom@example.com') }
      let(:resend) { { email: user.email } }

      response '200', 'generic answer (an email is sent only when it is allowed)' do
        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        context 'with an unverified user' do
          context 'with a valid request' do
            run_test! { expect(json['message']).to be_present }
          end

          it 'sends a new confirmation email' do
            expect { send_documented_request }.to have_enqueued_mail(UserMailer, :confirmation)
          end

          it 'sends an email whose token confirms the account' do
            ActionMailer::Base.deliveries.clear
            perform_enqueued_jobs { send_documented_request }

            post '/api/v1/auth/confirm-email', params: { token: last_mail_token }, as: :json

            expect(response).to have_http_status(:ok)
            expect(user.reload).to be_email_confirmed
          end

          it 'makes the link from the previous email stop working' do
            old_token = Tokens::EmailConfirmation.issue(user)
            send_documented_request

            post '/api/v1/auth/confirm-email', params: { token: old_token }, as: :json

            expect(json['code']).to eq('TOKEN_INVALID')
          end

          context 'when the email has other case and spaces' do
            let(:resend) { { email: '  MOM@example.com ' } }

            before { user }

            it 'still finds the user' do
              expect { send_documented_request }.to have_enqueued_mail(UserMailer, :confirmation)
            end
          end
        end

        context 'when the cooldown has not passed' do
          before { Tokens::EmailConfirmation.acquire_cooldown(user) }

          it 'sends nothing and answers 200' do
            expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :confirmation)
            expect(response).to have_http_status(:ok)
          end

          it 'sends the email again after the cooldown' do
            travel_to(61.seconds.from_now) do
              expect { send_documented_request }.to have_enqueued_mail(UserMailer, :confirmation)
            end
          end
        end

        context 'when another resend was just made' do
          before { post '/api/v1/auth/resend-confirmation', params: { email: user.email }, as: :json }

          it 'sends nothing' do
            expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :confirmation)
          end
        end

        context 'when the user has just registered' do
          let(:resend) { { email: 'new@example.com' } }

          before do
            post '/api/v1/auth/register', as: :json,
                                          params: { email: 'new@example.com', password: 'Password123',
                                                    first_name: 'Ira', last_name: 'Koval' }
          end

          it 'sends nothing' do
            expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :confirmation)
          end
        end

        {
          'an unknown email' => -> { 'nobody@example.com' },
          'an already confirmed user' => -> { create(:user, :confirmed).email },
          'a blocked user' => -> { create(:user, :blocked).email }
        }.each do |label, email|
          context "with #{label}" do
            let(:resend) { { email: instance_exec(&email) } }

            it 'sends nothing and answers 200 with a message' do
              expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :confirmation)
              expect(response).to have_http_status(:ok)
              expect(json['message']).to be_present
            end
          end
        end

        it 'returns identical responses for existing, unknown, confirmed and throttled emails' do
          throttled = create(:user, :unconfirmed)
          Tokens::EmailConfirmation.acquire_cooldown(throttled)
          emails = [ create(:user, :unconfirmed).email, 'nobody@example.com', create(:user, :confirmed).email,
                     throttled.email ]

          responses = emails.map do |email|
            post '/api/v1/auth/resend-confirmation', params: { email: email }, as: :json
            [ response.status, response.parsed_body ]
          end

          expect(responses.uniq.size).to eq(1)
        end

        context 'with an unknown email' do
          let(:resend) { { email: 'nobody@example.com' } }

          context 'without a language' do
            run_test! { expect(json['message']).to start_with('Якщо акаунт') }
          end

          context 'with Accept-Language: en' do
            let(:accept_language) { 'en' }

            run_test! { expect(json['message']).to start_with('If an account') }
          end
        end
      end

      response '400', 'email missing' do
        schema '$ref' => '#/components/schemas/error'

        context 'without an email' do
          let(:resend) { {} }

          run_test! do
            expect(json['code']).to eq('PARAMETER_MISSING')
            expect(json['details']).to include(a_hash_including('field' => 'email'))
          end
        end

        context 'with a blank email' do
          let(:resend) { { email: '' } }

          run_test!
        end
      end
    end
  end
end
