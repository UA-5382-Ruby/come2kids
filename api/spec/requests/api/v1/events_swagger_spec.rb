# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Events', type: :request do
  let(:organization) { create(:organization) }
  let(:category) { create(:category) }
  let(:published_event) do
    e = create(:event, organization: organization, category: category)
    create(:event_translation, event: e, title: 'Подія', description: 'Опис')
    e
  end

  it 'returns a paginated catalog' do
    get '/api/v1/events'
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to have_key('pagination')
  end

  path '/api/v1/events' do
    get 'List published events' do
      tags 'Events'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :pageSize, in: :query, type: :integer, required: false
      parameter name: :category_id, in: :query, type: :integer, required: false
      parameter name: :city, in: :query, type: :string, required: false
      parameter name: :organization_id, in: :query, type: :integer, required: false
      parameter name: :location_type, in: :query, type: :string, required: false
      parameter name: :date_from, in: :query, type: :string, required: false
      parameter name: :date_to, in: :query, type: :string, required: false
      parameter name: :q, in: :query, type: :string, required: false
      parameter name: :locale, in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false
      parameter name: :direction, in: :query, type: :string, required: false

      response '200', 'events list' do
        run_test!
      end

      response '400', 'invalid query parameters' do
        let(:sort) { 'bogus' }
        run_test!
      end
    end
  end

  path '/api/v1/events/{id}' do
    get 'Event details' do
      tags 'Events'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'event found' do
        let(:id) { published_event.id }
        run_test!
      end

      response '404', 'not found or not public' do
        let(:id) { 0 }
        run_test!
      end
    end
  end
end
