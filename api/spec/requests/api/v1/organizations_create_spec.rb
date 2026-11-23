# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Organizations: create', type: :request do
  let(:user) { create(:user) }
  let(:authorization) { "Bearer #{JwtService.encode(user)}" }
  let(:json) { response.parsed_body }

  before do
    Role.find_or_create_by(key: 'owner') do |role|
      role.name_uk = 'Власник'
      role.name_en = 'Owner'
    end
  end

  path '/api/v1/organizations' do
    parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization,
              description: 'Bearer access token'

    post 'Requests organization creation' do
      tags 'Organizations'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          organization: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Come2Kids Events' },
              description: { type: :string, example: 'Organizing the best events' },
              contact_email: { type: :string, example: 'contact@example.com' }
            },
            required: %w[name contact_email]
          }
        },
        required: %w[organization]
      }

      response '201', 'Organization request created successfully' do
        let(:body) do
          { organization: { name: 'New Org', description: 'Test desc', contact_email: 'neworg@example.com' } }
        end

        run_test!
      end

      response '422', 'Validation failed or user is already an owner' do
        let(:body) do
          { organization: { name: '', description: 'Test desc', contact_email: 'x@example.com' } }
        end

        run_test! { expect(json['code']).to eq('VALIDATION_ERROR') }
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error'

        let(:authorization) { nil }
        let(:body) do
          { organization: { name: 'New Org', description: 'Test desc', contact_email: 'x@example.com' } }
        end

        run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
      end
    end
  end
end
