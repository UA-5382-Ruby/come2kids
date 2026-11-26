# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1 Questions and Answers', type: :request do
  let(:organization) { create(:organization, :with_owner) }
  let(:event) { create(:event, organization: organization, status: :published) }
  let(:user) { create(:user) }
  let(:moderator) { create(:user, :moderator) }

    def auth_headers(account)
        token = JwtService.encode(account)
        { 'Authorization' => "Bearer #{token}" }
    end

  describe 'GET /api/v1/events/:event_id/questions' do
    it 'returns only visible questions with answers' do
      visible = create(:question, target: event, author: user)
      create(:answer, question: visible, author: organization.owner)
      create(:question, :hidden, target: event, author: user)

      get "/api/v1/events/#{event.id}/questions"

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body['data'].pluck('id')
      expect(ids).to eq([ visible.id ])
      expect(response.parsed_body['data'].first['answers'].size).to eq(1)
    end
  end

  describe 'POST /api/v1/events/:event_id/questions' do
    it 'creates a question for authenticated user' do
      post "/api/v1/events/#{event.id}/questions",
           params: { text: 'What age group is this for?' },
           headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['data']['text']).to eq('What age group is this for?')
    end
  end

  describe 'POST /api/v1/questions/:question_id/answers' do
    it 'allows organization owner to answer an event question' do
      question = create(:question, target: event, author: user)

      post "/api/v1/questions/#{question.id}/answers",
           params: { text: 'Ages 5 to 12.' },
           headers: auth_headers(organization.owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['data']['text']).to eq('Ages 5 to 12.')
    end

    it 'forbids regular user from answering' do
      question = create(:question, target: event, author: user)

      post "/api/v1/questions/#{question.id}/answers",
           params: { text: 'Not allowed' },
           headers: auth_headers(user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v1/questions/:id/hide' do
    it 'allows moderator to hide a question' do
      question = create(:question, target: event, author: user)

      patch "/api/v1/questions/#{question.id}/hide", headers: auth_headers(moderator)

      expect(response).to have_http_status(:ok)
      expect(question.reload.is_hidden).to be(true)
    end
  end

  describe 'DELETE /api/v1/questions/:id' do
    it 'allows author to delete own question' do
      question = create(:question, target: event, author: user)

      delete "/api/v1/questions/#{question.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:no_content)
      expect(Question.exists?(question.id)).to be(false)
    end
  end

  describe 'GET /api/v1/moderation/questions' do
    it 'returns platform questions for moderator' do
      platform_q = create(:question, :for_platform, author: user)
      create(:question, target: event, author: user)

      get '/api/v1/moderation/questions', headers: auth_headers(moderator)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq([ platform_q.id ])
    end
  end
end
