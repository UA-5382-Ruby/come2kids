# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Categories', type: :request do
  describe 'GET /api/v1/categories' do
    before do
      create(:category, name_uk: 'Спорт', name_en: 'Sport', position: 1)
      create(:category, name_uk: 'Мистецтво', name_en: 'Art', position: 2)
    end

    it 'returns categories ordered by position' do
      get '/api/v1/categories', params: { locale: 'uk' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].map { |c| c['name'] }).to eq([ 'Спорт', 'Мистецтво' ])
    end

    it 'returns english names for en locale' do
      get '/api/v1/categories', params: { locale: 'en' }

      expect(response.parsed_body['data'].map { |c| c['name'] }).to eq([ 'Sport', 'Art' ])
    end

    it 'exposes stable id and slug for catalog filtering' do
      get '/api/v1/categories', params: { locale: 'uk' }

      expect(response.parsed_body['data'].first).to include('id', 'slug')
    end
  end
end
