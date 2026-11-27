# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::EventReviews', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:past_event) { create(:event, :past) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.encode(user)}" } }

  describe 'GET /api/v1/events/:event_id/reviews' do
    it 'returns paginated reviews for an event without authentication' do
      review1 = create(:event_review, event: past_event, user: user, rating: 5, text: 'Чудово!')
      review2 = create(:event_review, event: past_event, user: other_user, rating: 4, text: 'Добре')
      create(:event_review, event: create(:event, :past))

      get "/api/v1/events/#{past_event.id}/reviews"

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('data').map { |item| item['id'] }
      expect(ids).to contain_exactly(review1.id, review2.id)
      expect(response.parsed_body.fetch('pagination')).to include('totalCount' => 2, 'page' => 1)
    end

    it 'returns 404 when event does not exist' do
      get '/api/v1/events/999999/reviews'

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['code']).to eq('NOT_FOUND')
    end
  end

  describe 'POST /api/v1/events/:event_id/reviews' do
    it 'returns 401 Unauthorized without token' do
      post "/api/v1/events/#{past_event.id}/reviews", params: { rating: 5, text: 'Супер' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a review when user holds a ticket and event has ended' do
      create(:ticket, user: user, event: past_event, status: 'valid')

      post "/api/v1/events/#{past_event.id}/reviews",
           params: { rating: 5, text: 'Дуже сподобалось!' },
           headers: headers

      expect(response).to have_http_status(:created)
      data = response.parsed_body.fetch('data')
      expect(data).to include(
        'event_id' => past_event.id,
        'user_id' => user.id,
        'rating' => 5,
        'text' => 'Дуже сподобалось!'
      )
      expect(data['author']).to include('id' => user.id, 'first_name' => user.first_name)
    end

    it 'returns 403 TICKET_REQUIRED when user has no ticket' do
      post "/api/v1/events/#{past_event.id}/reviews",
           params: { rating: 5 },
           headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('TICKET_REQUIRED')
    end

    it 'returns 422 EVENT_NOT_ENDED when event has not ended yet' do
      future_event = create(:event)
      create(:ticket, user: user, event: future_event, status: 'valid')

      post "/api/v1/events/#{future_event.id}/reviews",
           params: { rating: 5 },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('EVENT_NOT_ENDED')
    end

    it 'returns 409 REVIEW_ALREADY_EXISTS when user already reviewed the event' do
      create(:ticket, user: user, event: past_event, status: 'valid')
      create(:event_review, user: user, event: past_event)

      post "/api/v1/events/#{past_event.id}/reviews",
           params: { rating: 4 },
           headers: headers

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['code']).to eq('REVIEW_ALREADY_EXISTS')
    end

    it 'returns 422 VALIDATION_ERROR when rating is invalid' do
      create(:ticket, user: user, event: past_event, status: 'valid')

      post "/api/v1/events/#{past_event.id}/reviews",
           params: { rating: 6 },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('VALIDATION_ERROR')
    end

    it 'returns 404 when event does not exist' do
      post '/api/v1/events/999999/reviews', params: { rating: 5 }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT /api/v1/reviews/:id' do
    let!(:review) { create(:event_review, event: past_event, user: user, rating: 4, text: 'Добре') }

    it 'returns 401 Unauthorized without token' do
      put "/api/v1/reviews/#{review.id}", params: { rating: 5 }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'updates the review for its author' do
      put "/api/v1/reviews/#{review.id}",
          params: { rating: 5, text: 'Оновлений відгук' },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch('data')).to include('rating' => 5, 'text' => 'Оновлений відгук')
    end

    it 'returns 403 FORBIDDEN for another user' do
      other_headers = { 'Authorization' => "Bearer #{JwtService.encode(other_user)}" }

      put "/api/v1/reviews/#{review.id}",
          params: { rating: 1 },
          headers: other_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('FORBIDDEN')
    end

    it 'returns 422 VALIDATION_ERROR when rating is invalid' do
      put "/api/v1/reviews/#{review.id}",
          params: { rating: 0 },
          headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('VALIDATION_ERROR')
    end

    it 'returns 404 when review does not exist' do
      put '/api/v1/reviews/999999', params: { rating: 5 }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/reviews/:id' do
    let!(:review) { create(:event_review, event: past_event, user: user) }

    it 'returns 401 Unauthorized without token' do
      delete "/api/v1/reviews/#{review.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'deletes the review for its author' do
      expect do
        delete "/api/v1/reviews/#{review.id}", headers: headers
      end.to change(EventReview, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 403 FORBIDDEN for another user' do
      other_headers = { 'Authorization' => "Bearer #{JwtService.encode(other_user)}" }

      expect do
        delete "/api/v1/reviews/#{review.id}", headers: other_headers
      end.not_to change(EventReview, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['code']).to eq('FORBIDDEN')
    end

    it 'returns 404 when review does not exist' do
      delete '/api/v1/reviews/999999', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
