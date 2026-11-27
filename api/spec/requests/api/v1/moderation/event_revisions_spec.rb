# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Moderation: event revisions', type: :request do
  let(:authorization) { "Bearer #{JwtService.encode(moderator)}" }
  let(:decision) { {} }
  let(:revision) { submit_revision(city: 'Львів') }
  let(:id) { revision.id }

  def moderator
    @moderator ||= create(:user, :moderator)
  end

  def organization
    @organization ||= create(:organization)
  end

  def editor
    @editor ||= create(:company_member, :owner, organization: organization).user
  end

  def event
    @event ||= create(:event, :published, organization: organization, created_by: editor,
      address: 'вул. Хрещатик, 1', city: 'Київ').tap do |record|
      create(:event_translation, event: record, title: 'Майстерня')
      create(:ticket_type, event: record, name: 'Дорослий', price: 100, total_quantity: 10)
    end
  end

  def submit_revision(**attributes)
    Events::Revisions::Upsert.call(event: event, actor: editor, attributes: attributes).value!
  end

  revision_response = {
    type: :object, properties: { data: { '$ref' => '#/components/schemas/moderation_event_revision' } },
    required: %w[data]
  }

  describe '/api/v1/moderation/event-revisions' do
    path '/api/v1/moderation/event-revisions' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization

      get 'Queue of edits of published events with old and new values (US-6.2, FR-MOD-6)' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :status, in: :query, type: :string, required: false,
                  description: 'under_review (default), any revision status, or all'
        parameter name: :event_id, in: :query, type: :integer, required: false
        parameter name: :sort, in: :query, type: :string, required: false, enum: %w[created_at updated_at]
        parameter name: :page, in: :query, type: :integer, required: false
        parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size

        before do
          revision
          create(:event_revision, status: 'withdrawn')
        end

        response '200', 'pending revisions with the changed fields side by side' do
          schema type: :object,
                 properties: {
                   data: { type: :array, items: { '$ref' => '#/components/schemas/moderation_event_revision' } },
                   pagination: { '$ref' => '#/components/schemas/pagination' }
                 },
                 required: %w[data pagination]

          run_test! do
            expect(json['data'].pluck('id')).to eq([ revision.id ])
            item = json['data'].first
            expect(item['changes']).to eq([ { 'field' => 'city', 'old' => 'Київ', 'new' => 'Львів' } ])
            expect(item['proposed']).to include('city' => 'Львів', 'address' => 'вул. Хрещатик, 1')
            expect(item['event']).to include('id' => event.id, 'title' => 'Майстерня', 'status' => 'published')
            expect(item['submitted_by']).to include('id' => editor.id)
          end
        end

        response '400', 'unknown status filter' do
          schema '$ref' => '#/components/schemas/error'

          let(:status) { 'pending' }

          run_test! { expect(json['code']).to eq('BAD_REQUEST') }
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

  describe '/api/v1/moderation/event-revisions/{id}/approve' do
    path '/api/v1/moderation/event-revisions/{id}/approve' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Apply an edit to the published event (under_review → approved)' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]

        response '200', 'applied; the editor is emailed' do
          schema revision_response

          context 'with a pending revision' do
            run_test! do
              expect(json['data']).to include('status' => 'approved', 'reviewed_by_id' => moderator.id, 'changes' => nil)
              expect(event.reload).to have_attributes(city: 'Львів', status: 'published')
              expect(ModerationLog.for_entity(revision).last)
                .to have_attributes(decision: 'approved', moderator_id: moderator.id)
            end
          end

          it 'emails the editor and writes the activity log' do
            expect { send_documented_request }
              .to have_enqueued_mail(ModerationMailer, :revision_decision)
              .and have_enqueued_job(ActivityLogJob)
          end

          context 'when only texts change' do
            let(:revision) { submit_revision(translations: [ { locale: 'uk', title: 'Нова назва' } ]) }

            it 'applies the new title' do
              send_documented_request
              expect(event.reload.title).to eq('Нова назва')
            end
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'not a moderator (the editor cannot approve their own edit)' do
          let(:authorization) { "Bearer #{JwtService.encode(editor)}" }

          run_test! { expect(event.reload.city).to eq('Київ') }
        end

        response '404', 'revision not found' do
          let(:id) { 0 }

          run_test!
        end

        response '409', 'not pending, the event is no longer published, or the organization is not approved' do
          schema '$ref' => '#/components/schemas/error'

          context 'with a withdrawn revision' do
            before { revision.update!(status: 'withdrawn') }

            run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
          end

          context 'with a cancelled event' do
            before { event.update!(status: 'cancelled') }

            run_test! do
              expect(revision.reload).to be_pending
              expect(event.reload).to have_attributes(status: 'cancelled', city: 'Київ')
            end
          end

          context 'with an event of a blocked organization' do
            before { organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'Fraud') }

            run_test! do
              expect(revision.reload).to be_pending
              expect(ModerationLog.for_entity(revision)).to be_empty
            end
          end
        end

        response '422', 'the revision can no longer be applied' do
          schema '$ref' => '#/components/schemas/error'

          # The edit removes a ticket type that was still unsold when it was submitted; tickets sold since.
          let(:revision) do
            submit_revision(city: 'Львів', ticket_types: [ { name: 'Дитячий', price: 50, total_quantity: 5 } ])
          end

          before do
            revision
            allow(Events::TicketDemand).to receive(:for).and_return(1)
          end

          run_test! do
            expect(revision.reload).to be_pending
            expect(event.reload.city).to eq('Київ')
            expect(ModerationLog.for_entity(revision)).to be_empty
          end
        end
      end
    end
  end

  describe '/api/v1/moderation/event-revisions/{id}/reject' do
    path '/api/v1/moderation/event-revisions/{id}/reject' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Reject an edit (reason required)' do
        tags 'Moderation'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body,
                  schema: { type: :object, properties: { reason: { type: :string } }, required: %w[reason] }

        response '200', 'rejected; the event stays unchanged and the editor is emailed' do
          schema revision_response

          let(:decision) { { reason: 'The new address is incomplete' } }

          context 'with a reason' do
            run_test! do
              expect(revision.reload).to have_attributes(status: 'rejected', reviewed_by_id: moderator.id,
                rejection_reason: 'The new address is incomplete')
              expect(revision.reviewed_at).to be_present
              expect(event.reload.city).to eq('Київ')
              expect(ModerationLog.for_entity(revision).last)
                .to have_attributes(decision: 'rejected', reason: 'The new address is incomplete')
            end
          end

          it 'emails the editor with the reason' do
            expect { send_documented_request }
              .to have_enqueued_mail(ModerationMailer, :revision_decision)
              .with(revision, 'rejected', 'The new address is incomplete')
          end
        end

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

        response '409', 'not pending' do
          schema '$ref' => '#/components/schemas/error'

          let(:decision) { { reason: 'Too late' } }

          before { revision.update!(status: 'approved') }

          run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
        end

        response '422', 'reason missing' do
          schema '$ref' => '#/components/schemas/error'

          run_test! do
            expect(json['details']).to include(hash_including('field' => 'reason'))
            expect(revision.reload).to be_pending
          end
        end
      end
    end
  end
end
