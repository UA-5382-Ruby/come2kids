# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Users: own profile', type: :request do
  let(:user) do
    create(:user, first_name: 'Olena', last_name: 'Test', email: 'original@example.com', preferred_locale: 'en')
  end
  let(:authorization) { "Bearer #{JwtService.encode(user)}" }
  let(:json) { response.parsed_body }

  path '/api/v1/users/me' do
    parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization,
              description: 'Bearer access token'

    get 'Show the profile of the current user' do
      tags 'Users'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'profile' do
        schema '$ref' => '#/components/schemas/user_profile'

        run_test! do
          expect(json).to include('id' => user.id, 'email' => user.email, 'first_name' => 'Olena')
        end
      end

      response '401', 'not authenticated' do
        schema '$ref' => '#/components/schemas/error'

        let(:authorization) { nil }

        run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
      end
    end

    put 'Update the profile of the current user (email cannot be changed)' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      parameter name: :profile, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              first_name: { type: :string },
              last_name: { type: :string },
              phone: { type: :string },
              birth_date: { type: :string, format: :date },
              city: { type: :string },
              preferred_locale: { type: :string, enum: %w[uk en] }
            }
          }
        },
        required: %w[user]
      }

      response '200', 'profile updated' do
        schema '$ref' => '#/components/schemas/user_profile'

        let(:profile) { { user: { first_name: 'UpdatedName', city: 'Kyiv', preferred_locale: 'en' } } }

        context 'with allowed fields' do
          run_test! do
            expect(user.reload).to have_attributes(first_name: 'UpdatedName', city: 'Kyiv', preferred_locale: 'en')
          end
        end

        context 'when the request also tries to change the email' do
          let(:profile) { { user: { first_name: 'UpdatedName', email: 'new_hacked@example.com' } } }

          run_test! do
            expect(user.reload).to have_attributes(first_name: 'UpdatedName', email: 'original@example.com')
          end
        end
      end

      response '401', 'not authenticated' do
        let(:authorization) { nil }
        let(:profile) { { user: { first_name: 'X' } } }

        run_test!
      end

      response '422', 'invalid profile' do
        context 'when first_name is blank' do
          let(:profile) { { user: { first_name: '' } } }

          run_test! { expect(json['errors']).to include('First name не може бути порожнім') }
        end

        context 'when preferred_locale is not supported' do
          let(:profile) { { user: { preferred_locale: 'fr' } } }

          run_test! { expect(json['errors']).to include('Preferred locale не включено до переліку') }
        end
      end
    end
  end
end
