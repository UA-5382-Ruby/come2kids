# frozen_string_literal: true

require 'swagger_helper'

# rubocop:disable RSpec/RepeatedExample
RSpec.describe 'Api::V1::Public::Organizations', type: :request do
  # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:approved_org) do
    org = create(:organization, status: 'approved', city: 'Kyiv', average_rating: 4.5)
    org.organization_translations.create!(
      locale: 'uk',
      name: 'Дитячі свята',
      description: 'Організація дитячих свят'
    )
    org.organization_translations.create!(
      locale: 'en',
      name: 'Kids Events',
      description: 'Kids events organization'
    )
    org
  end

  let(:blocked_org) do
    create(:organization, status: 'blocked', block_reason: 'Порушення правил')
  end

  let(:pending_org) do
    create(:organization, status: 'pending_approval')
  end

  before do
    approved_org
    blocked_org
    pending_org
  end

  path '/api/v1/public/organizations' do
    get 'List publicly visible organizations' do
      tags 'Public Organizations'
      produces 'application/json'

      parameter name: :search, in: :query, type: :string, required: false,
                description: 'Search by organization name'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of records to return (max 100)'
      parameter name: :offset, in: :query, type: :integer, required: false,
                description: 'Number of records to skip'
      parameter name: 'Accept-Language', in: :header, type: :string, required: false,
                description: 'Preferred language (uk or en)'

      response '200', 'organizations list' do
        schema type: :object, properties: {
          organizations: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :integer },
                slug: { type: :string },
                name: { type: :string },
                description: { type: :string },
                contact_email: { type: :string },
                city: { type: [ :string, :null ] },
                average_rating: { type: [ :number, :null ] },
                reviews_count: { type: :integer },
                published_events_count: { type: :integer }
              }
            }
          },
          meta: {
            type: :object,
            properties: {
              total: { type: :integer }
            }
          }
        }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['organizations'].size).to eq(1)
          expect(json['organizations'].first['slug']).to eq(approved_org.slug)
          expect(json['meta']['total']).to eq(1)
          expect(json['organizations'].first['average_rating']).to eq(4.5)
        end
      end

      response '200', 'filtered by search term' do
        let(:search) { 'Дитячі' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['organizations'].size).to eq(1)
          expect(json['organizations'].first['name']).to eq('Дитячі свята')
        end
      end

      response '200', 'with Accept-Language: uk returns Ukrainian translations' do
        # rubocop:disable RSpec/VariableName
        let(:'Accept-Language') { 'uk' }
        # rubocop:enable RSpec/VariableName

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['organizations'].first['name']).to eq('Дитячі свята')
        end
      end

      response '200', 'with Accept-Language: en returns English translations' do
        # rubocop:disable RSpec/VariableName
        let(:'Accept-Language') { 'en' }
        # rubocop:enable RSpec/VariableName

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['organizations'].first['name']).to eq('Kids Events')
        end
      end
    end
  end

  path '/api/v1/public/organizations/{id}' do
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Organization slug'
    parameter name: 'Accept-Language', in: :header, type: :string, required: false,
              description: 'Preferred language (uk or en)'

    get 'Show organization details' do
      tags 'Public Organizations'
      produces 'application/json'

      response '200', 'organization details' do
        let(:id) { approved_org.slug }

        schema type: :object, properties: {
          organization: {
            type: :object,
            properties: {
              id: { type: :integer },
              slug: { type: :string },
              name: { type: :string },
              description: { type: :string },
              contact_email: { type: :string },
              phone: { type: [ :string, :null ] },
              website: { type: [ :string, :null ] },
              address: { type: [ :string, :null ] },
              city: { type: [ :string, :null ] },
              average_rating: { type: [ :number, :null ] },
              reviews_count: { type: :integer },
              published_events_count: { type: :integer }
            }
          }
        }

        run_test! do |response|
          json = JSON.parse(response.body)
          org = json['organization']
          expect(org['slug']).to eq(approved_org.slug)
          expect(org['average_rating']).to eq(4.5)
          expect(org['published_events_count']).to be_a(Integer)
        end
      end

      response '404', 'organization not found' do
        let(:id) { 'nonexistent-slug' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['code']).to eq('NOT_FOUND')
        end
      end

      response '404', 'blocked organization not accessible' do
        let(:id) { blocked_org.slug }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['code']).to eq('NOT_FOUND')
        end
      end

      response '404', 'pending organization not accessible' do
        let(:id) { pending_org.slug }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['code']).to eq('NOT_FOUND')
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
# rubocop:enable RSpec/RepeatedExample
