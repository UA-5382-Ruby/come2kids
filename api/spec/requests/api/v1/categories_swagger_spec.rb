# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Categories', type: :request do
  it 'returns the category list envelope' do
    get '/api/v1/categories', params: { locale: 'uk' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to have_key('data')
  end

  path '/api/v1/categories' do
    get 'List event categories' do
      tags 'Categories'
      produces 'application/json'
      parameter name: :locale, in: :query, type: :string, required: false

      response '200', 'category list' do
        run_test!
      end
    end
  end
end
