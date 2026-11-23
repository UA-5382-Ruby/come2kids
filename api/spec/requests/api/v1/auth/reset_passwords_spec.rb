# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth: reset password', type: :request do
  let(:user) { create(:user, email: 'user@example.com', password: 'OldPassword123') }
  let(:raw_token) { Tokens::PasswordReset.issue(user) }
  let(:valid_params) { { token: raw_token, password: 'NewPassword123', password_confirmation: 'NewPassword123' } }

  before { Tokens::PasswordReset.redis.flushdb }

  path '/api/v1/auth/reset-password' do
    post 'Set a new password with the token from the reset email' do
      tags 'Auth'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Accept-Language', in: :header, type: :string, required: false, getter: :accept_language
      parameter name: :reset, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string },
          password: { type: :string, description: 'At least 8 characters with a letter and a digit' },
          password_confirmation: { type: :string }
        },
        required: %w[token password]
      }

      let(:reset) { valid_params }

      response '200', 'password changed' do
        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        run_test! do
          expect(json['message']).to eq(I18n.t('auth.password_reset_success'))
          expect(user.reload.authenticate('NewPassword123')).to eq(user)
        end
      end

      response '400', 'required parameters missing' do
        schema type: :object, properties: { code: { type: :string } }, required: %w[code]

        let(:reset) { { token: raw_token } }

        run_test! { expect(json['code']).to eq('PARAMETER_MISSING') }
      end

      response '422', 'token invalid or used, or the password is invalid' do
        schema type: :object, properties: { code: { type: :string } }, required: %w[code]

        context 'with an unknown token' do
          let(:reset) { valid_params.merge(token: 'invalid-token') }

          run_test! { expect(json['code']).to eq('TOKEN_INVALID') }
        end

        context 'with a token that was already used' do
          before { post '/api/v1/auth/reset-password', params: valid_params, as: :json }

          run_test! { expect(json['code']).to eq('TOKEN_USED') }
        end

        context 'with a weak password' do
          let(:reset) { valid_params.merge(password: 'weak', password_confirmation: 'weak') }

          context 'without a language' do
            run_test! do
              expect(json['code']).to eq('VALIDATION_ERROR')
              expect(json['details'].first).to include('field' => 'password', 'error' => 'complexity')
            end
          end

          context 'with Accept-Language: uk' do
            let(:accept_language) { 'uk' }

            run_test! { expect(json['message']).to eq('Дані не пройшли перевірку.') }
          end
        end

        context 'with a mismatched confirmation' do
          let(:reset) { valid_params.merge(password_confirmation: 'DifferentPassword123') }

          run_test! do
            expect(json['code']).to eq('VALIDATION_ERROR')
            expect(json['details'].pluck('field')).to include('password_confirmation')
          end
        end
      end
    end
  end
end
