# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Organizations', type: :request do
  before do
    Role.find_or_create_by(key: 'owner') do |role|
      role.name_uk = 'Власник'
      role.name_en = 'Owner'
    end
  end

  path '/api/v1/organizations/{id}' do
    put 'Updates organization information' do
      tags 'Organizations'
      consumes 'application/json'
      produces 'application/json'

      # ✅ ЯВНЕ ОГОЛОШЕННЯ ЗАГОЛОВКА
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token'

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Organization ID'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          organization: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Updated Name' },
              description: { type: :string, example: 'Updated description' },
              contact_email: { type: :string, example: 'new@example.com' },
              phone: { type: :string, example: '+380501234567' },
              website: { type: :string, example: 'https://example.com' },
              address: { type: :string, example: 'Khreshchatyk 1' },
              city: { type: :string, example: 'Kyiv' }
            }
          }
        },
        required: %w[organization]
      }

      response '200', 'Organization updated successfully' do
        let(:organization) { create_organization_with_owner }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner_of(organization))}" }
        let(:id) { organization.id }
        let(:body) do
          { organization: { name: 'Updated Org', description: 'New desc', contact_email: 'updated@example.com' } }
        end

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:organization) { create_organization_with_owner }
        let(:id) { organization.id }
        let(:'Authorization') { 'Bearer invalid_token' }
        let(:body) { { organization: { name: 'Hacked' } } }

        run_test!
      end

      response '403', 'Forbidden - user is not the owner' do
        let(:organization) { create_organization_with_owner }
        let(:id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(create(:user))}" }
        let(:body) { { organization: { name: 'Hacked Name' } } }

        run_test!
      end

      response '404', 'Organization not found' do
        let(:id) { 999_999 }
        let(:'Authorization') { "Bearer #{JwtService.encode(create(:user))}" }
        let(:body) { { organization: { name: 'Updated Org' } } }

        run_test!
      end

      response '422', 'Validation failed' do
        let(:organization) { create_organization_with_owner }
        let(:id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner_of(organization))}" }
        let(:body) { { organization: { name: '', contact_email: 'not-an-email' } } }

        run_test!
      end
    end
  end

  def owner_of(organization)
    organization.company_members.find_by(role: Role.find_by(key: 'owner')).user
  end

  def create_organization_with_owner
    owner = create(:user)
    org = Organization.create!(
      slug: "test-org-#{SecureRandom.hex(4)}",
      contact_email: 'test@example.com',
      status: 'pending_approval'
    )
    org.organization_translations.create!(
      locale: I18n.locale,
      name: 'Test Org',
      description: 'Description'
    )
    CompanyMember.create!(
      user: owner,
      organization: org,
      role: Role.find_by(key: 'owner')
    )
    org
  end
end