# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth: login', type: :request do
  let(:user) { create(:user) }
  let(:password) { 'Password123' }
  let(:json) { response.parsed_body }

  # Rate limits live in Rails.cache; start every example with a clean counter.
  before { Rails.cache.clear }

  path '/api/v1/auth/login' do
    post 'Log in with email and password' do
      tags 'Auth'
      description 'Returns a short-lived JWT access token. There is no refresh token: the client logs in again ' \
                  'when it expires. A blocked user gets 403 USER_BLOCKED with an appeal token (FR-APP-1).'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'user@demo.com' },
          password: { type: :string, example: 'User12345' }
        },
        required: %w[email password]
      }

      let(:credentials) { { email: user.email, password: password } }

      response '200', 'access token issued' do
        schema type: :object,
               properties: {
                 access_token: { type: :string },
                 token_type: { type: :string, example: 'Bearer' },
                 expires_in: { type: :integer, example: 900 }
               },
               required: %w[access_token token_type expires_in]

        context 'with valid credentials' do
          run_test! do
            expect(json).to include('token_type' => 'Bearer', 'expires_in' => JwtService::ACCESS_TTL.to_i)
            expect(JwtService.decode(json['access_token'])['sub']).to eq(user.id.to_s)
            expect(json.keys).to contain_exactly('access_token', 'token_type', 'expires_in')
            expect(response.headers['Set-Cookie']).to be_blank
          end
        end

        context 'when the email is in another case' do
          let(:credentials) { { email: user.email.upcase, password: password } }

          run_test!
        end
      end

      response '401', 'invalid credentials' do
        schema '$ref' => '#/components/schemas/error'

        context 'with a wrong password' do
          let(:password) { 'wrong-pass1' }

          run_test! { expect(json['code']).to eq('INVALID_CREDENTIALS') }
        end

        context 'with an unknown email (same error, no account enumeration)' do
          let(:credentials) { { email: 'nobody@example.com', password: password } }

          run_test! { expect(json['code']).to eq('INVALID_CREDENTIALS') }
        end

        { 'soft-deleted' => { deleted_at: Time.current }, 'inactive' => { is_active: false } }.each do |state, attrs|
          context "when the account is #{state}" do
            let(:user) { create(:user, **attrs) }

            run_test! { expect(json['code']).to eq('INVALID_CREDENTIALS') }
          end
        end
      end

      response '403', 'email not confirmed or user blocked' do
        schema '$ref' => '#/components/schemas/error'

        context 'when the email is not confirmed' do
          let(:user) { create(:user, :unconfirmed) }

          run_test! { expect(json['code']).to eq('EMAIL_NOT_CONFIRMED') }
        end

        context 'when the user is blocked' do
          let(:user) { create(:user, :blocked) }

          run_test! do
            expect(json['code']).to eq('USER_BLOCKED')
            expect(json['details'].first['message']).to eq('Spam')
            expect(json).not_to have_key('access_token')
            expect(JwtService.decode(json['appeal_token'])['scope']).to eq('appeal')
          end
        end
      end

      response '422', 'email or password missing' do
        schema '$ref' => '#/components/schemas/error'

        let(:credentials) { {} }

        run_test! do
          expect(json['code']).to eq('VALIDATION_FAILED')
          expect(json['details'].pluck('field')).to eq(%w[email password])
        end
      end

      response '429', 'too many attempts' do
        schema '$ref' => '#/components/schemas/error'

        context 'when one email was tried five times' do
          before { 5.times { post '/api/v1/auth/login', params: { email: user.email, password: 'x1' }, as: :json } }

          run_test! { expect(json['code']).to eq('TOO_MANY_REQUESTS') }
        end

        context 'when one IP made twenty attempts, even for different emails' do
          before do
            20.times { |i| post '/api/v1/auth/login', params: { email: "probe#{i}@example.com" }, as: :json }
          end

          run_test!
        end
      end
    end
  end

  it 'has no refresh or logout endpoints' do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:api_v1_auth_refresh_path)
    expect(Rails.application.routes.url_helpers).not_to respond_to(:api_v1_auth_logout_path)
  end
end
