# frozen_string_literal: true

require 'swagger_helper'

# rswag keeps every documented response in one example group and requires `Authorization`.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VariableName
RSpec.describe 'Api::V1::Organizations::Images', type: :request do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:event) { create(:event, :draft, organization: organization) }
  let(:organization_id) { organization.id }
  let(:event_id) { event.id }
  let(:Authorization) { "Bearer #{JwtService.encode(owner)}" }
  let(:kind) { 'gallery' }
  let(:image) { uploaded_file }

  path '/api/v1/organizations/{organization_id}/events/{event_id}/images' do
    post 'Upload an event image' do
      tags 'Event images'
      description 'Stores one banner or gallery image with Active Storage. ' \
                  'A banner upload replaces the previous banner only after the new file is valid.'
      security [ bearerAuth: [] ]
      consumes 'multipart/form-data'
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :event_id, in: :path, schema: { type: :integer }
      parameter name: :image, in: :formData, schema: { type: :string, format: :binary }
      parameter name: :kind, in: :formData, schema: { type: :string, enum: %w[banner gallery] }

      response '201', 'image stored' do
        schema '$ref' => '#/components/schemas/eventMediaResponse'

        run_test! do |response|
          body = JSON.parse(response.body).fetch('data')

          expect(body['kind']).to eq('gallery')
          expect(body['content_type']).to eq('image/png')
          expect(body['url']).to be_present
          expect(event.event_media.gallery.count).to eq(1)
        end
      end

      response '422', 'invalid image' do
        schema '$ref' => '#/components/schemas/error'
        let(:image) { uploaded_file(content_type: 'text/plain', body: 'hello', filename: 'notes.txt') }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body['code']).to eq('VALIDATION_ERROR')
          expect(body['details'].map { |detail| detail['field'] }).to include('file')
          expect(event.event_media.count).to eq(0)
        end
      end

      response '401', 'missing or invalid token' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { 'Bearer invalid' }

        run_test!
      end

      response '403', 'caller cannot change these images' do
        schema '$ref' => '#/components/schemas/error'
        let(:Authorization) { "Bearer #{JwtService.encode(create(:user))}" }

        run_test!
      end

      response '404', 'event not found' do
        schema '$ref' => '#/components/schemas/error'
        let(:event_id) { 0 }

        run_test!
      end
    end
  end

  path '/api/v1/organizations/{organization_id}/events/{event_id}/images/order' do
    patch 'Reorder gallery images' do
      tags 'Event images'
      security [ bearerAuth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :event_id, in: :path, schema: { type: :integer }
      parameter name: :payload, in: :body, schema: { '$ref' => '#/components/schemas/eventImageOrder' }

      response '200', 'gallery reordered' do
        schema '$ref' => '#/components/schemas/eventMediaList'
        let!(:first_image) { create(:event_medium, event: event, position: 0) }
        let!(:second_image) { create(:event_medium, event: event, position: 1) }
        let(:payload) { { image_ids: [ second_image.id, first_image.id ] } }

        run_test! do |response|
          ids = JSON.parse(response.body).fetch('data').map { |item| item['id'] }

          expect(ids).to eq([ second_image.id, first_image.id ])
        end
      end

      response '422', 'order is not the full gallery' do
        schema '$ref' => '#/components/schemas/error'
        let!(:first_image) { create(:event_medium, event: event, position: 0) }
        let!(:second_image) { create(:event_medium, event: event, position: 1) }
        let(:payload) { { image_ids: [ first_image.id ] } }

        run_test! do
          expect(event.event_media.gallery.order(:position).pluck(:id)).to eq([ first_image.id, second_image.id ])
        end
      end
    end
  end

  path '/api/v1/organizations/{organization_id}/events/{event_id}/images/{id}' do
    delete 'Delete an event image' do
      tags 'Event images'
      security [ bearerAuth: [] ]
      produces 'application/json'
      parameter name: :organization_id, in: :path, schema: { type: :integer }
      parameter name: :event_id, in: :path, schema: { type: :integer }
      parameter name: :id, in: :path, schema: { type: :integer }

      response '204', 'image deleted' do
        let(:id) { create(:event_medium, event: event).id }

        run_test! do
          expect(event.event_media.count).to eq(0)
        end
      end

      response '404', 'image not found' do
        schema '$ref' => '#/components/schemas/error'
        let(:id) { 0 }

        run_test!
      end
    end
  end

  describe 'image rules' do
    def post_image(file: uploaded_file, image_kind: 'gallery', headers: auth_headers(owner), target: event)
      post "/api/v1/organizations/#{organization.id}/events/#{target.id}/images",
           params: { image: file, kind: image_kind }, headers: headers
    end

    it 'replaces the banner only when the new file is valid' do
      post_image(image_kind: 'banner')
      original_id = event.event_media.banner.pick(:id)

      post_image(file: uploaded_file(content_type: 'text/plain', body: 'nope', filename: 'notes.txt'), image_kind: 'banner')

      expect(response).to have_http_status(422)
      expect(event.event_media.banner.pluck(:id)).to eq([ original_id ])

      post_image(image_kind: 'banner')

      expect(response).to have_http_status(:created)
      expect(event.event_media.banner.count).to eq(1)
      expect(event.event_media.banner.pick(:id)).not_to eq(original_id)
    end

    it 'rejects an eleventh gallery image and stores nothing' do
      EventMedia::MAX_GALLERY_IMAGES.times { |index| create(:event_medium, event: event, position: index) }

      expect { post_image }.not_to change(EventMedia, :count)
      expect(response).to have_http_status(422)
    end

    it 'rejects an event that is under review or published' do
      %w[under_review published].each do |status|
        locked = create(:event, organization: organization, status: status)
        post_image(target: locked)

        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'rejects a blocked organization' do
      organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'spam')

      post_image

      expect(response).to have_http_status(:forbidden)
    end

    it 'lets a manager upload to a rejected event' do
      manager = create(:company_member, :manager, organization: organization).user
      rejected = create(:event, organization: organization, status: 'rejected')

      post_image(headers: auth_headers(manager), target: rejected)

      expect(response).to have_http_status(:created)
      expect(rejected.event_media.gallery.count).to eq(1)
    end

    it 'rejects a request without a token' do
      post "/api/v1/organizations/#{organization.id}/events/#{event.id}/images",
           params: { image: uploaded_file, kind: 'gallery' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  def uploaded_file(content_type: 'image/png', body: EventImageFixture::PNG_BYTES, filename: 'photo.png')
    file = Tempfile.new([ 'event-image', File.extname(filename) ])
    file.binmode
    file.write(body)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, content_type, true, original_filename: filename)
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VariableName
