  # frozen_string_literal: true

  require 'rails_helper'

  RSpec.describe 'Api::V1::Events', type: :request do
    let(:organization) { create(:organization) }
    let(:category) { create(:category) }

    def publish_event(attrs = {})
      event = create(:event, { organization: organization, category: category }.merge(attrs))
      create(:event_translation, event: event)
      event
    end

    def get_events(params = {})
      get '/api/v1/events', params: params
    end

    describe 'GET /api/v1/events' do
      context 'when catalog is empty' do
        before { get_events }

        it 'returns ok' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns empty data' do
          expect(response.parsed_body['data']).to eq([])
        end
      end

      context 'when statuses are mixed' do
        before do
          publish_event
          create(:event, :draft, organization: organization)
          create(:event, :cancelled, organization: organization)
          blocked = create(:organization, status: 'blocked', blocked_at: Time.current, block_reason: 'spam')
          create(:event, organization: blocked)
          get_events
        end

        it 'returns only published approved events' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with category filter' do
        let(:other_category) { create(:category) }

        before do
          publish_event
          publish_event(category: other_category)
          get_events(category_id: category.id)
        end

        it 'returns matching category only' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with city filter' do
        before do
          publish_event(city: 'Kyiv')
          publish_event(city: 'Lviv')
          get_events(city: 'Lviv')
        end

        it 'returns matching city only' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with online filter' do
        before do
          publish_event
          online = create(:event, :online, organization: organization, category: category)
          create(:event_translation, event: online)
          get_events(location_type: 'online')
        end

        it 'returns online events only' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with date range' do
        before do
          publish_event(start_at: 2.days.from_now, end_at: 2.days.from_now + 2.hours)
          publish_event(start_at: 10.days.from_now, end_at: 10.days.from_now + 2.hours)
          get_events(date_from: 5.days.from_now.iso8601)
        end

        it 'returns events after date_from' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with text search' do
        before do
          event = create(:event, organization: organization, category: category)
          create(:event_translation, event: event, title: 'Майстер-клас з малювання')
          publish_event
          get_events(q: 'малювання', locale: 'uk')
        end

        it 'returns matching events' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with english locale search' do
        before do
          target = publish_event
          create(:event_translation, :en, event: target, title: 'Painting workshop')
          publish_event
          get_events(q: 'Painting', locale: 'en')
        end

        it 'returns matching english events' do
          expect(response.parsed_body['data'].size).to eq(1)
        end
      end

      context 'with descending sort' do
        before do
          publish_event(start_at: 1.day.from_now, end_at: 1.day.from_now + 2.hours)
          publish_event(start_at: 3.days.from_now, end_at: 3.days.from_now + 2.hours)
          get_events(sort: 'date', direction: 'desc')
        end

        it 'returns later event first' do
          data = response.parsed_body['data']
          expect(data.first['start_at'] > data.last['start_at']).to be(true)
        end
      end

      context 'with pagination' do
        before do
          3.times { publish_event }
          get_events(pageSize: 2, page: 1)
        end

        it 'returns requested page size' do
          expect(response.parsed_body['data'].size).to eq(2)
        end

        it 'returns total count' do
          expect(response.parsed_body['pagination']['totalCount']).to eq(3)
        end

        it 'returns total pages' do
          expect(response.parsed_body['pagination']['totalPages']).to eq(2)
        end
      end

      context 'with oversized page size' do
        before { get_events(pageSize: 999) }

        it 'returns bad request' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'with unknown sort column' do
        before { get_events(sort: 'password') }

        it 'returns bad request' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'with invalid direction' do
        before { get_events(direction: 'sideways') }

        it 'returns bad request' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'with invalid date' do
        before { get_events(date_from: 'not-a-date') }

        it 'returns bad request' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'with invalid location type' do
        before { get_events(location_type: 'hybrid') }

        it 'returns bad request' do
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
