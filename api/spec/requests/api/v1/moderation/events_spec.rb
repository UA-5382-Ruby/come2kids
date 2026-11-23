# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Moderation: events', type: :request do
  let(:moderator) { create(:user, :moderator) }
  let(:authorization) { "Bearer #{JwtService.encode(moderator)}" }
  let(:decision) { {} }

  event_response = {
    type: :object, properties: { data: { '$ref' => '#/components/schemas/moderation_event' } }, required: %w[data]
  }

  describe '/api/v1/moderation/events' do
    path '/api/v1/moderation/events' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization

      get 'Queue of new events (US-6.2)' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :status, in: :query, type: :string, required: false,
                  description: 'under_review (default), any event status, or all'
        parameter name: :organization_id, in: :query, type: :integer, required: false
        parameter name: :category_id, in: :query, type: :integer, required: false
        parameter name: :sort, in: :query, type: :string, required: false, enum: %w[submitted_at created_at start_at]
        parameter name: :page, in: :query, type: :integer, required: false
        parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size

        let!(:event_in_review) { create(:event, :under_review, :with_translations) }

        before { create(:event) }

        response '200', 'events under review with every language version' do
          schema type: :object,
                 properties: {
                   data: { type: :array, items: { '$ref' => '#/components/schemas/moderation_event' } },
                   pagination: { '$ref' => '#/components/schemas/pagination' }
                 },
                 required: %w[data pagination]

          run_test! do
            expect(json['data'].pluck('id')).to eq([ event_in_review.id ])
            expect(json['data'].first['translations'].pluck('locale')).to contain_exactly('uk', 'en')
            expect(json['data'].first['organization']).to include('id' => event_in_review.organization_id)
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'not a moderator' do
          let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

          run_test! { expect(json['code']).to eq('FORBIDDEN') }
        end
      end
    end
  end

  describe '/api/v1/moderation/events/{id}/approve' do
    path '/api/v1/moderation/events/{id}/approve' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Publish an event (under_review → published)' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]

        let(:event) { create(:event, :under_review) }
        let(:id) { event.id }

        response '200', 'published; the creator is emailed' do
          schema event_response

          context 'with an event under review' do
            run_test! do
              expect(event.reload).to have_attributes(status: 'published', reviewed_by_id: moderator.id)
              expect(event.published_at).to be_present
              expect(Event.publicly_visible).to include(event)
              expect(ModerationLog.for_entity(event).last.decision).to eq('approved')
            expect(event.event_status_histories.last)
              .to have_attributes(from_status: 'under_review', to_status: 'published', changed_by_id: moderator.id)
            end
          end

          it 'emails the creator' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :event_decision)
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'not a moderator (the organization owner cannot publish)' do
          let(:authorization) do
            "Bearer #{JwtService.encode(create(:company_member, :owner, organization: event.organization).user)}"
          end

          run_test!
        end

        response '409', 'not under review, or the organization is not approved' do
          schema '$ref' => '#/components/schemas/error'

          context 'with a draft' do
            before { event.update!(status: 'draft') }

            run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
          end

          context 'with an event of a blocked organization' do
            before { event.organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'Fraud') }

            run_test! { expect(event.reload).to be_under_review }
          end
        end
      end
    end
  end

  describe '/api/v1/moderation/events/{id}/reject' do
    path '/api/v1/moderation/events/{id}/reject' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Reject an event (reason required)' do
        tags 'Moderation'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body,
                  schema: { type: :object, properties: { reason: { type: :string } }, required: %w[reason] }

        let(:event) { create(:event, :under_review) }
        let(:id) { event.id }

        response '401', 'not authenticated' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { nil }

          run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
        end

        response '403', 'not a moderator' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

          run_test! { expect(json['code']).to eq('FORBIDDEN') }
        end

        response '200', 'rejected; the creator is emailed' do
          schema event_response

          let(:decision) { { reason: 'Missing description' } }

          context 'with a reason' do
            run_test! do
              expect(event.reload).to have_attributes(status: 'rejected', rejection_reason: 'Missing description')
            expect(event.event_status_histories.last)
              .to have_attributes(to_status: 'rejected', reason: 'Missing description')
            end
          end

          it 'emails the creator' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :event_decision)
          end
        end

        response '422', 'reason missing' do
          schema '$ref' => '#/components/schemas/error'

          run_test! { expect(event.reload).to be_under_review }
        end
      end
    end
  end
end
