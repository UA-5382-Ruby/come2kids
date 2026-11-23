# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth: forgot password', type: :request do
  let(:user) { create(:user, email: 'user@example.com', first_name: 'Olena') }

  before do
    ActiveJob::Base.queue_adapter = :test
    Tokens::PasswordReset.redis.flushdb
  end

  path '/api/v1/auth/forgot-password' do
    post 'Request a password reset link' do
      tags 'Auth'
      description 'Always answers with the same message, so it does not reveal whether an account exists.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Accept-Language', in: :header, type: :string, required: false, getter: :accept_language
      parameter name: :request_body, in: :body, schema: {
        type: :object, properties: { email: { type: :string, format: :email } }, required: %w[email]
      }

      let(:request_body) { { email: user.email } }

      response '200', 'generic answer (the email is sent only to an existing, active user)' do
        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        context 'with an existing user' do
          run_test! { expect(json['message']).to eq(I18n.t('auth.forgot_password_sent')) }
        end

        it 'sends the reset email to an existing user' do
          expect { send_documented_request }.to have_enqueued_mail(UserMailer, :password_reset)
        end

        context 'with an unknown email' do
          let(:request_body) { { email: 'nobody@example.com' } }

          it 'sends nothing and answers the same' do
            expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :password_reset)
            expect(response).to have_http_status(:ok)
            expect(json['message']).to eq(I18n.t('auth.forgot_password_sent'))
          end

          context 'with Accept-Language: uk' do
            let(:accept_language) { 'uk' }

            run_test! do
              expect(json['message'])
                .to eq('Якщо акаунт з такою електронною адресою існує, ми надіслали посилання для скидання пароля.')
            end
          end
        end

        context 'with a blocked user' do
          before { user.update!(blocked_at: Time.current, block_reason: 'Violation') }

          it 'sends nothing and answers the same' do
            expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :password_reset)
            expect(response).to have_http_status(:ok)
            expect(json['message']).to eq(I18n.t('auth.forgot_password_sent'))
          end
        end

        context 'when another request was just made (cooldown)' do
          before { post '/api/v1/auth/forgot-password', params: { email: user.email }, as: :json }

          it 'sends nothing and answers the same' do
            expect { send_documented_request }.not_to have_enqueued_mail(UserMailer, :password_reset)
            expect(response).to have_http_status(:ok)
            expect(json['message']).to eq(I18n.t('auth.forgot_password_sent'))
          end
        end
      end

      response '400', 'email missing' do
        schema type: :object, properties: { code: { type: :string } }, required: %w[code]

        context 'without an email' do
          let(:request_body) { {} }

          run_test! { expect(json['code']).to eq('PARAMETER_MISSING') }
        end

        context 'with a blank email' do
          let(:request_body) { { email: '   ' } }

          run_test! { expect(json['code']).to eq('PARAMETER_MISSING') }
        end
      end
    end
  end
end
