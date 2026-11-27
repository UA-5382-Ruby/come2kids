# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::OrganizationReviews', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:past_event) { create(:event, :past, organization: organization) }

  def auth_headers(account)
    token = JwtService.encode(account)
    { 'Authorization' => "Bearer #{token}" }
  end

  describe 'GET /api/v1/organizations/:organization_id/reviews' do
    it 'returns paginated organization reviews for guests' do
      create(:organization_review, organization: organization, user: user, rating: 5, text: 'Супер!')
      create(:organization_review, organization: organization, user: other_user, rating: 4, text: 'Добре')

      get "/api/v1/organizations/#{organization.id}/reviews"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['data'].size).to eq(2)
      expect(body['data'].first).to include('id', 'organization_id', 'user_id', 'rating', 'text', 'author')
      expect(body.fetch('pagination')).to include('totalCount' => 2, 'page' => 1)
    end

    it 'returns 404 when organization does not exist' do
      get '/api/v1/organizations/999999/reviews'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/organizations/:organization_id/reviews' do
    it 'creates a review when user attended a past event of the organization' do
      create(:ticket, user: user, event: past_event, status: 'valid')

      post "/api/v1/organizations/#{organization.id}/reviews",
           params: { rating: 5, text: 'Чудова організація!' },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['data']['rating']).to eq(5)
      expect(body['data']['text']).to eq('Чудова організація!')
      expect(body['data']['organization_id']).to eq(organization.id)
      expect(body['data']['author']['id']).to eq(user.id)
    end

    it 'returns 401 for unauthenticated user' do
      post "/api/v1/organizations/#{organization.id}/reviews",
           params: { rating: 5 },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when user has not attended any finished event of the organization' do
      post "/api/v1/organizations/#{organization.id}/reviews",
           params: { rating: 5 },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('ATTENDANCE_REQUIRED')
    end

    it 'returns 403 when user only has a ticket for a future event' do
      future_event = create(:event, organization: organization)
      create(:ticket, user: user, event: future_event, status: 'valid')

      post "/api/v1/organizations/#{organization.id}/reviews",
           params: { rating: 5 },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('ATTENDANCE_REQUIRED')
    end

    it 'returns 409 when user already reviewed the organization' do
      create(:ticket, user: user, event: past_event, status: 'valid')
      create(:organization_review, organization: organization, user: user)

      post "/api/v1/organizations/#{organization.id}/reviews",
           params: { rating: 4 },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['code']).to eq('REVIEW_ALREADY_EXISTS')
    end

    it 'returns 422 when rating is invalid' do
      create(:ticket, user: user, event: past_event, status: 'valid')

      post "/api/v1/organizations/#{organization.id}/reviews",
           params: { rating: 6 },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 when organization does not exist' do
      post '/api/v1/organizations/999999/reviews',
           params: { rating: 5 },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT /api/v1/organization_reviews/:id' do
    let!(:review) { create(:organization_review, organization: organization, user: user, rating: 4, text: 'Старий текст') }

    it 'updates the review for its author' do
      put "/api/v1/organization_reviews/#{review.id}",
          params: { rating: 5, text: 'Оновлений текст' },
          headers: auth_headers(user),
          as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['data']['rating']).to eq(5)
      expect(body['data']['text']).to eq('Оновлений текст')
    end

    it 'returns 401 for unauthenticated user' do
      put "/api/v1/organization_reviews/#{review.id}",
          params: { rating: 5 },
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when another user tries to update the review' do
      put "/api/v1/organization_reviews/#{review.id}",
          params: { rating: 1 },
          headers: auth_headers(other_user),
          as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 when rating is invalid' do
      put "/api/v1/organization_reviews/#{review.id}",
          params: { rating: 0 },
          headers: auth_headers(user),
          as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 when review does not exist' do
      put '/api/v1/organization_reviews/999999',
          params: { rating: 5 },
          headers: auth_headers(user),
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/organization_reviews/:id' do
    let!(:review) { create(:organization_review, organization: organization, user: user) }

    it 'deletes the review for its author' do
      expect do
        delete "/api/v1/organization_reviews/#{review.id}", headers: auth_headers(user)
      end.to change(OrganizationReview, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 401 for unauthenticated user' do
      delete "/api/v1/organization_reviews/#{review.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when another user tries to delete the review' do
      delete "/api/v1/organization_reviews/#{review.id}", headers: auth_headers(other_user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 when review does not exist' do
      delete '/api/v1/organization_reviews/999999', headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end
end
