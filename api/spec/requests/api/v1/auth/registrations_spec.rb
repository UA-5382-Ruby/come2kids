# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth: registration', type: :request do
  include ActiveJob::TestHelper

  let(:valid_params) do
    { email: 'mom@example.com', password: 'Password123', first_name: 'Olena', last_name: 'Shevchenko' }
  end

  def error_details(field, error)
    json['details'].select { |detail| detail['field'] == field && detail['error'] == error }
  end

  path '/api/v1/auth/register' do
    post 'Register a new user and send the confirmation email' do
      tags 'Auth'
      description 'Creates an unverified user and emails a single-use confirmation link valid for 24 hours.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Accept-Language', in: :header, type: :string, required: false, getter: :accept_language,
                description: 'uk (default) or en; also the default preferred_locale'
      parameter name: :locale, in: :query, type: :string, required: false, description: 'Overrides Accept-Language'
      parameter name: :registration, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          password: { type: :string, description: 'At least 8 characters with a letter and a digit' },
          password_confirmation: { type: :string },
          first_name: { type: :string, maxLength: 100 },
          last_name: { type: :string, maxLength: 100 },
          preferred_locale: { type: :string, enum: %w[uk en] }
        },
        required: %w[email password first_name last_name]
      }

      let(:registration) { valid_params }

      response '201', 'user registered' do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     first_name: { type: :string },
                     last_name: { type: :string },
                     preferred_locale: { type: :string },
                     email_confirmed: { type: :boolean },
                     created_at: { type: :string, format: 'date-time' }
                   }
                 }
               },
               required: %w[message user]

        context 'with valid data' do
          run_test! do
            expect(json['message']).to be_present
            expect(json['user']).to include('email' => 'mom@example.com', 'first_name' => 'Olena',
                                            'last_name' => 'Shevchenko', 'preferred_locale' => 'uk',
                                            'email_confirmed' => false)
            expect(User.find_by(email: 'mom@example.com')).not_to be_email_confirmed
            expect(json['user'].keys).not_to include('password', 'password_digest', 'password_confirmation')
            expect(response.body).not_to include('Password123')
          end
        end

        it 'creates the user and enqueues the confirmation email' do
          expect { send_documented_request }.to change(User, :count).by(1)
            .and have_enqueued_mail(UserMailer, :confirmation)
        end

        it 'stores a confirmation token in Redis for 24 hours' do
          send_documented_request

          user = User.find_by!(email: 'mom@example.com')
          ttl = Tokens::EmailConfirmation.redis.ttl(Tokens::EmailConfirmation.user_key(user.id))
          expect(ttl).to be_within(5).of(24.hours.to_i)
        end

        it 'keeps only the digest of the token in Redis, never the raw token' do
          ActionMailer::Base.deliveries.clear
          perform_enqueued_jobs { send_documented_request }

          raw_token = ActionMailer::Base.deliveries.last.text_part.decoded[/token=([\w-]+)/, 1]
          keys = Tokens::EmailConfirmation.redis.keys
          expect(raw_token).to be_present
          expect(keys).to include("email_confirmation:token:#{Digest::SHA256.hexdigest(raw_token)}")
          expect(keys).not_to include(a_string_including(raw_token))
        end

        context 'with an email in mixed case and spaces' do
          let(:registration) { valid_params.merge(email: '  Mom@Example.COM ') }

          run_test! { expect(User.last.email).to eq('mom@example.com') }
        end

        context 'when the request language is English' do
          let(:accept_language) { 'en' }

          run_test! { expect(json['user']['preferred_locale']).to eq('en') }
        end

        context 'with an explicit preferred_locale' do
          let(:registration) { valid_params.merge(preferred_locale: 'en') }

          run_test! { expect(json['user']['preferred_locale']).to eq('en') }
        end

        context 'with attributes the client must not set' do
          let(:registration) { valid_params.merge(platform_role: 'moderator', email_confirmed_at: Time.current) }

          run_test! do
            user = User.find_by!(email: 'mom@example.com')
            expect(user.platform_role).to eq('user')
            expect(user).not_to be_email_confirmed
          end
        end

        context 'with a password of exactly 8 characters with a letter and a digit' do
          let(:registration) { valid_params.merge(password: 'abcdefg1') }

          run_test!
        end
      end

      response '422', 'validation failed' do
        schema '$ref' => '#/components/schemas/error'

        context 'with a duplicate email' do
          before { create(:user, email: 'mom@example.com') }

          context 'with the same email' do
            run_test! do
              expect(json['code']).to eq('VALIDATION_ERROR')
              expect(error_details('email', 'taken')).not_to be_empty
            end
          end

          it 'creates no user and sends no email' do
            expect { send_documented_request }.not_to change(User, :count)
            expect(enqueued_jobs).to be_empty
          end

          context 'when the email differs only in case' do
            let(:registration) { valid_params.merge(email: 'MOM@EXAMPLE.COM') }

            run_test! { expect(error_details('email', 'taken')).not_to be_empty }
          end
        end

        { 'fewer than 8 characters' => 'Ab1', 'no digit' => 'PasswordOnly', 'no letter' => '12345678' }
          .each do |label, password|
            context "with a password with #{label}" do
              let(:registration) { valid_params.merge(password: password) }

              run_test! { expect(error_details('password', 'complexity')).not_to be_empty }
            end
          end

        context 'with a weak password' do
          let(:registration) { valid_params.merge(password: 'weak') }

          it 'creates neither a user nor a token' do
            expect { send_documented_request }
              .not_to change { [ User.count, Tokens::EmailConfirmation.redis.keys.size ] }
          end

          context 'with Accept-Language: en' do
            let(:accept_language) { 'en' }

            run_test! do
              message = json['details'].find { |detail| detail['error'] == 'complexity' }['message']
              expect(message).to include('at least 8 characters')
            end
          end
        end

        {
          'a mismatched password confirmation' => [ { password_confirmation: 'Different123' },
                                                    'password_confirmation', 'confirmation' ],
          'an invalid email format' => [ { email: 'not-an-email' }, 'email', 'invalid' ],
          'an unsupported preferred_locale' => [ { preferred_locale: 'de' }, 'preferred_locale', 'inclusion' ],
          'a name longer than 100 characters' => [ { first_name: 'a' * 101 }, 'first_name', 'too_long' ]
        }.each do |label, (changes, field, error)|
          context "with #{label}" do
            let(:registration) { valid_params.merge(changes) }

            run_test! { expect(error_details(field, error)).not_to be_empty }
          end
        end

        context 'with an empty body' do
          let(:registration) { {} }

          context 'without a language (Ukrainian by default)' do
            run_test! do
              expect(json['code']).to eq('VALIDATION_ERROR')
              expect(json['details'].pluck('field')).to include('email', 'password', 'first_name', 'last_name')
              expect(json['message']).to eq('Дані не пройшли перевірку.')
            end
          end

          context 'with Accept-Language: en-US,en;q=0.9' do
            let(:accept_language) { 'en-US,en;q=0.9' }

            run_test! do
              expect(json['code']).to eq('VALIDATION_ERROR')
              expect(json['message']).to eq('Validation failed.')
            end
          end

          context 'when the locale parameter overrides the header' do
            let(:accept_language) { 'uk' }
            let(:locale) { 'en' }

            run_test! { expect(json['message']).to eq('Validation failed.') }
          end

          context 'with an unsupported language' do
            let(:accept_language) { 'fr-FR,fr;q=0.9' }

            run_test! { expect(json['message']).to eq('Дані не пройшли перевірку.') }
          end
        end
      end
    end
  end
end
