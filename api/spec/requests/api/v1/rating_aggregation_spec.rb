# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rating aggregation', type: :request do
  describe 'GET /api/v1/events/:id' do
    let(:organization) { create(:organization, status: :approved) }
    let(:event) { create(:event, organization: organization, status: :published) }
    let(:user_one) { create(:user) }
    let(:user_two) { create(:user) }

    context 'when event and organization have no reviews' do
      it 'returns nil average_rating and zero reviews_count' do
        get "/api/v1/events/#{event.id}"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include('average_rating' => nil, 'reviews_count' => 0)
        expect(response.parsed_body['organization']).to include('average_rating' => nil, 'reviews_count' => 0)
      end
    end

    context 'when event reviews are created, updated, and destroyed' do
      it 'returns updated event average_rating and reviews_count' do
        review = create(:event_review, event: event, user: user_one, rating: 4)
        create(:event_review, event: event, user: user_two, rating: 5)

        get "/api/v1/events/#{event.id}"
        expect(response.parsed_body).to include('average_rating' => 4.5, 'reviews_count' => 2)

        review.update!(rating: 2)
        get "/api/v1/events/#{event.id}"
        expect(response.parsed_body).to include('average_rating' => 3.5, 'reviews_count' => 2)

        review.destroy!
        get "/api/v1/events/#{event.id}"
        expect(response.parsed_body).to include('average_rating' => 5.0, 'reviews_count' => 1)
      end
    end

    context 'when organization reviews are created and destroyed' do
      it 'returns updated organization average_rating and reviews_count' do
        review = create(:organization_review, organization: organization, user: user_one, rating: 5)
        create(:organization_review, organization: organization, user: user_two, rating: 4)

        get "/api/v1/events/#{event.id}"
        expect(response.parsed_body['organization']).to include('average_rating' => 4.5, 'reviews_count' => 2)

        review.destroy!
        get "/api/v1/events/#{event.id}"
        expect(response.parsed_body['organization']).to include('average_rating' => 4.0, 'reviews_count' => 1)
      end
    end
  end
end
