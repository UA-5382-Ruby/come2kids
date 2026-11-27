# frozen_string_literal: true

require 'swagger_helper'

# OpenAPI documentation for subscriptions (US-12.1). Behaviour is covered in subscriptions_spec.rb.
RSpec.describe 'Api::V1::Subscriptions (OpenAPI)', type: :request do
  let(:authorization) { "Bearer #{JwtService.encode(user)}" }

  def user
    @user ||= create(:user)
  end

  subscription_schema = {
    type: :object,
    properties: {
      id: { type: :integer },
      target_type: { type: :string, enum: %w[event organization] },
      target_id: { type: :integer },
      target_name: { type: :string, nullable: true },
      created_at: { type: :string, format: 'date-time' }
    },
    required: %w[id target_type target_id created_at]
  }

  path '/api/v1/subscriptions' do
    post 'Subscribe to a published event or an approved organization' do
      tags 'Subscriptions'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          target_type: { type: :string, enum: %w[event organization] },
          target_id: { type: :integer }
        },
        required: %w[target_type target_id]
      }

      response '201', 'subscribed' do
        schema type: :object, properties: { data: subscription_schema }
        let(:body) { { target_type: 'event', target_id: create(:event, :published).id } }

        run_test!
      end

      response '409', 'already subscribed (SUBSCRIPTION_ALREADY_EXISTS)' do
        schema '$ref' => '#/components/schemas/error'
        let(:body) { { target_type: 'event', target_id: create(:subscription, user: user).target_id } }

        run_test!
      end

      response '422', 'unpublished event or blocked organization (SUBSCRIPTION_TARGET_UNAVAILABLE)' do
        schema '$ref' => '#/components/schemas/error'
        let(:body) { { target_type: 'organization', target_id: create(:organization, :blocked).id } }

        run_test!
      end

      response '401', 'not authenticated' do
        let(:authorization) { nil }
        let(:body) { { target_type: 'event', target_id: 1 } }

        run_test!
      end
    end
  end

  path '/api/v1/subscriptions/my' do
    get "List the current user's subscriptions" do
      tags 'Subscriptions'
      produces 'application/json'
      security [ bearerAuth: [] ]
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :target_type, in: :query, type: :string, enum: %w[event organization], required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size

      response '200', 'subscriptions' do
        schema type: :object, properties: {
          data: { type: :array, items: subscription_schema },
          pagination: { '$ref' => '#/components/schemas/pagination' }
        }

        let!(:subscription) { create(:subscription, user: user) }

        run_test! { expect(json['data'].pluck('id')).to eq([ subscription.id ]) }
      end
    end
  end

  path '/api/v1/subscriptions/{id}' do
    delete 'Unsubscribe' do
      tags 'Subscriptions'
      security [ bearerAuth: [] ]
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      response '204', 'unsubscribed' do
        let(:id) { create(:subscription, user: user).id }

        run_test!
      end

      response '403', "another user's subscription" do
        let(:id) { create(:subscription).id }

        run_test!
      end
    end
  end

  path '/api/v1/subscriptions/unsubscribe' do
    get 'One-click unsubscribe from an email link (no login)' do
      tags 'Subscriptions'
      produces 'application/json'
      parameter name: :token, in: :query, type: :string, required: true

      response '200', 'unsubscribed (also when already unsubscribed)' do
        let(:token) { Subscriptions::UnsubscribeToken.generate(create(:subscription)) }

        run_test!
      end

      response '422', 'invalid token (TOKEN_INVALID)' do
        schema '$ref' => '#/components/schemas/error'
        let(:token) { 'tampered' }

        run_test!
      end
    end
  end
end
