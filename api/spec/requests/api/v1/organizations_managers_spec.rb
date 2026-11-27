# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Organizations::Managers', type: :request do
  before do
    Role.find_or_create_by!(key: 'owner') do |r|
      r.name_uk = 'Власник'
      r.name_en = 'Owner'
    end
    Role.find_or_create_by!(key: 'manager') do |r|
      r.name_uk = 'Менеджер'
      r.name_en = 'Manager'
    end
  end

  let(:owner) { create(:user) }
  let(:manager) { create(:user) }
  let(:regular_user) { create(:user) }

  let(:organization) do
    org = create(:organization, status: 'approved')
    create(:company_member, organization: org, user: owner, role: Role.find_by!(key: 'owner'))
    create(:company_member, organization: org, user: manager, role: Role.find_by!(key: 'manager'))
    org
  end

  # ✅ КРИТИЧНО: Оголошуємо параметр Authorization ОДИН РАЗ на рівні path
  # і використовуємо його в кожному HTTP-методі
  path '/api/v1/organizations/{organization_id}/managers' do
    parameter name: :organization_id, in: :path, type: :integer, required: true

    get 'List organization managers' do
      tags 'Organizations'
      produces 'application/json'

      # ✅ ОГОЛОШЕННЯ ЗАГОЛОВКА (без нього Rswag не передасть токен)
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token'

      response '200', 'managers list' do
        schema type: :object, properties: {
          managers: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                email: { type: :string },
                first_name: { type: :string },
                last_name: { type: :string },
                role: { type: :string },
                added_at: { type: :string, format: 'date-time' }
              }
            }
          }
        }
        let(:organization_id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner)}" }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:organization_id) { organization.id }
        let(:'Authorization') { 'Bearer invalid_token' }
        run_test!
      end
    end

    post 'Add a manager to the organization' do
      tags 'Organizations'
      consumes 'application/json'

      # ✅ ОГОЛОШЕННЯ ЗАГОЛОВКА
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { email: { type: :string, example: 'newmanager@example.com' } },
        required: %w[email]
      }

      response '201', 'manager added' do
        let(:organization_id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner)}" }
        let(:body) { { email: regular_user.email } }
        run_test!
      end

      response '404', 'user not found' do
        let(:organization_id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner)}" }
        let(:body) { { email: 'unknown@example.com' } }
        run_test!
      end

      response '422', 'already a member' do
        let(:organization_id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner)}" }
        let(:body) { { email: manager.email } }
        run_test!
      end

      response '403', 'forbidden (not owner)' do
        let(:organization_id) { organization.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(manager)}" }
        let(:body) { { email: regular_user.email } }
        run_test!
      end
    end
  end

  path '/api/v1/organizations/{organization_id}/managers/{user_id}' do
    parameter name: :organization_id, in: :path, type: :integer, required: true
    parameter name: :user_id, in: :path, type: :integer, required: true

    delete 'Remove a manager from the organization' do
      tags 'Organizations'

      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token'

      response '200', 'manager removed' do
        let(:organization_id) { organization.id }
        let(:user_id) { manager.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner)}" }
        run_test!
      end

      response '403', 'forbidden (not owner)' do
        let(:organization_id) { organization.id }
        let(:user_id) { regular_user.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(manager)}" }
        run_test!
      end

      response '404', 'not a member' do
        let(:organization_id) { organization.id }
        let(:user_id) { regular_user.id }
        let(:'Authorization') { "Bearer #{JwtService.encode(owner)}" }
        run_test!
      end
    end
  end
end
