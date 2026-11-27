# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Subscriptions', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:event) { create(:event, :published) }
  let(:organization) { create(:organization) }

  describe 'POST /api/v1/subscriptions' do
    it 'requires authentication' do
      post '/api/v1/subscriptions', params: { target_type: 'event', target_id: event.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'subscribes to a published event' do
      post '/api/v1/subscriptions', params: { target_type: 'event', target_id: event.id }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['data']).to include('target_type' => 'event', 'target_id' => event.id)
      expect(user.subscriptions.sole.target).to eq(event)
    end

    it 'subscribes to an approved organization' do
      post '/api/v1/subscriptions', params: { target_type: 'organization', target_id: organization.id },
                                    headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['data']).to include('target_type' => 'organization')
    end

    it 'returns 409 when already subscribed' do
      create(:subscription, user: user, target: event)

      post '/api/v1/subscriptions', params: { target_type: 'event', target_id: event.id }, headers: headers

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['code']).to eq('SUBSCRIPTION_ALREADY_EXISTS')
    end

    it 'rejects an unpublished event' do
      draft = create(:event, :draft)

      post '/api/v1/subscriptions', params: { target_type: 'event', target_id: draft.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('SUBSCRIPTION_TARGET_UNAVAILABLE')
    end

    it 'rejects a cancelled event' do
      event.update!(status: 'cancelled_by_organizer', cancelled_at: Time.current)

      post '/api/v1/subscriptions', params: { target_type: 'event', target_id: event.id }, headers: headers

      expect(response.parsed_body['code']).to eq('SUBSCRIPTION_TARGET_UNAVAILABLE')
    end

    it 'rejects a blocked organization' do
      blocked = create(:organization, :blocked)

      post '/api/v1/subscriptions', params: { target_type: 'organization', target_id: blocked.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('SUBSCRIPTION_TARGET_UNAVAILABLE')
    end

    it 'rejects an unknown target type' do
      post '/api/v1/subscriptions', params: { target_type: 'user', target_id: user.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('VALIDATION_FAILED')
    end

    it 'returns 404 for a missing target' do
      post '/api/v1/subscriptions', params: { target_type: 'event', target_id: 0 }, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 400 when target_id is missing' do
      post '/api/v1/subscriptions', params: { target_type: 'event' }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /api/v1/subscriptions/my' do
    it 'lists only the current user subscriptions' do
      own_event = create(:subscription, user: user, target: event)
      own_org = create(:subscription, user: user, target: organization)
      create(:subscription)

      get '/api/v1/subscriptions/my', headers: headers

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body['data'].pluck('id')
      expect(ids).to contain_exactly(own_event.id, own_org.id)
      expect(response.parsed_body['pagination']).to include('totalCount' => 2)
    end

    it 'filters by target type' do
      create(:subscription, user: user, target: event)
      own_org = create(:subscription, user: user, target: organization)

      get '/api/v1/subscriptions/my', params: { target_type: 'organization' }, headers: headers

      expect(response.parsed_body['data'].pluck('id')).to eq([ own_org.id ])
    end

    it 'rejects an unknown target type filter' do
      get '/api/v1/subscriptions/my', params: { target_type: 'user' }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'DELETE /api/v1/subscriptions/:id' do
    it 'unsubscribes' do
      subscription = create(:subscription, user: user, target: event)

      delete "/api/v1/subscriptions/#{subscription.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Subscription.exists?(subscription.id)).to be(false)
    end

    it "does not delete another user's subscription" do
      subscription = create(:subscription, target: event)

      delete "/api/v1/subscriptions/#{subscription.id}", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(Subscription.exists?(subscription.id)).to be(true)
    end
  end

  describe 'GET /api/v1/subscriptions/unsubscribe' do
    it 'unsubscribes with a signed token and without login' do
      subscription = create(:subscription, user: user, target: event)
      token = Subscriptions::UnsubscribeToken.generate(subscription)

      get '/api/v1/subscriptions/unsubscribe', params: { token: token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']).to eq('unsubscribed' => true)
      expect(Subscription.exists?(subscription.id)).to be(false)
    end

    it 'is harmless when repeated' do
      subscription = create(:subscription, user: user, target: event)
      token = Subscriptions::UnsubscribeToken.generate(subscription)

      2.times { get '/api/v1/subscriptions/unsubscribe', params: { token: token } }

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a tampered token' do
      subscription = create(:subscription, user: user, target: event)

      get '/api/v1/subscriptions/unsubscribe', params: { token: "#{Subscriptions::UnsubscribeToken.generate(subscription)}x" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('TOKEN_INVALID')
      expect(Subscription.exists?(subscription.id)).to be(true)
    end

    it 'rejects a missing token' do
      get '/api/v1/subscriptions/unsubscribe'

      expect(response.parsed_body['code']).to eq('TOKEN_INVALID')
    end
  end
end
