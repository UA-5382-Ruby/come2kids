# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Moderation: organizations', type: :request do
  let(:moderator) { create(:user, :moderator) }
  let(:authorization) { "Bearer #{JwtService.encode(moderator)}" }

  reason_body = { type: :object, properties: { reason: { type: :string, maxLength: 2000 } } }
  organization_response = {
    type: :object, properties: { data: { '$ref' => '#/components/schemas/moderation_organization' } },
    required: %w[data]
  }

  describe '/api/v1/moderation/organizations' do
    path '/api/v1/moderation/organizations' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization

      get 'Organization queue (US-6.1)' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :status, in: :query, type: :string, required: false,
                  description: 'pending_approval (default; alias pending), approved, rejected, blocked or all'
        parameter name: :city, in: :query, type: :string, required: false
        parameter name: :sort, in: :query, type: :string, required: false, enum: %w[created_at updated_at]
        parameter name: :direction, in: :query, type: :string, required: false, enum: %w[asc desc]
        parameter name: :page, in: :query, type: :integer, required: false
        parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size

        let!(:pending_organization) { create(:organization, :pending) }

        before { create(:organization) }

        response '200', 'organizations' do
          schema type: :object,
                 properties: {
                   data: { type: :array, items: { '$ref' => '#/components/schemas/moderation_organization' } },
                   pagination: { '$ref' => '#/components/schemas/pagination' }
                 },
                 required: %w[data pagination]

          context 'without a status (waiting for approval)' do
            run_test! do
              expect(json['data'].pluck('id')).to eq([ pending_organization.id ])
              expect(json['pagination']).to include('totalCount' => 1)
            end
          end

          context 'with status=pending' do
            let(:status) { 'pending' }

            run_test! { expect(json['data'].pluck('id')).to eq([ pending_organization.id ]) }
          end

          context 'with status=all' do
            let(:status) { 'all' }

            run_test! { expect(json['pagination']['totalCount']).to eq(2) }
          end
        end

        response '400', 'unknown status' do
          schema '$ref' => '#/components/schemas/error'

          let(:status) { 'nope' }

          run_test! { expect(json['details'].first['field']).to eq('status') }
        end

        response '401', 'not authenticated' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { nil }

          run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
        end

        response '403', 'not a moderator' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { "Bearer #{JwtService.encode(create(:company_member, :owner).user)}" }

          run_test! { expect(json['code']).to eq('FORBIDDEN') }
        end
      end
    end
  end

  describe '/api/v1/moderation/organizations/{id}/approve' do
    path '/api/v1/moderation/organizations/{id}/approve' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Approve an organization (pending_approval → approved)' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]

        let(:organization) { create(:organization, :pending, :with_owner) }
        let(:id) { organization.id }

        response '200', 'approved; the owner is emailed' do
          schema organization_response

          context 'with a pending organization' do
            run_test! do
              expect(json['data']).to include('status' => 'approved', 'approved_by_id' => moderator.id)
              expect(organization.reload).to be_approved
              expect(ModerationLog.for_entity(organization).last)
                .to have_attributes(decision: 'approved', moderator_id: moderator.id)
            end
          end

          it 'emails the owner and writes the activity log' do
            expect { send_documented_request }
              .to have_enqueued_mail(ModerationMailer, :organization_decision)
              .and have_enqueued_job(ActivityLogJob)
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'not a moderator (the owner cannot approve)' do
          let(:authorization) { "Bearer #{JwtService.encode(organization.owner)}" }

          run_test! { expect(json['code']).to eq('FORBIDDEN') }
        end

        response '404', 'organization not found' do
          let(:id) { 0 }

          run_test!
        end

        response '409', 'organization is not waiting for approval' do
          schema '$ref' => '#/components/schemas/error'

          before { organization.update!(status: 'approved', approved_at: Time.current) }

          run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
        end
      end
    end
  end

  describe '/api/v1/moderation/organizations/{id}/reject' do
    path '/api/v1/moderation/organizations/{id}/reject' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Reject an organization (reason required)' do
        tags 'Moderation'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body, schema: reason_body.merge(required: %w[reason])

        let(:organization) { create(:organization, :pending, :with_owner) }
        let(:id) { organization.id }
        let(:decision) { {} }

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

        response '200', 'rejected; the owner is emailed' do
          schema organization_response

          let(:decision) { { reason: 'No contact details' } }

          context 'with a reason' do
            run_test! do
              expect(organization.reload).to have_attributes(status: 'rejected', rejection_reason: 'No contact details')
              expect(ModerationLog.for_entity(organization).last)
                .to have_attributes(decision: 'rejected', reason: 'No contact details')
            end
          end

          it 'emails the owner' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :organization_decision)
          end
        end

        response '422', 'reason missing' do
          schema '$ref' => '#/components/schemas/error'

          context 'without a reason' do
            run_test! do
              expect(json['code']).to eq('VALIDATION_FAILED')
              expect(json['details'].first['field']).to eq('reason')
              expect(organization.reload).to be_pending_approval
            end
          end

          context 'with a reason that is not text' do
            let(:decision) { { reason: false } }

            run_test!('rejects it instead of storing "false"') do
              expect(json['details'].first['field']).to eq('reason')
              expect(organization.reload).to be_pending_approval
            end
          end
        end
      end
    end
  end

  describe '/api/v1/moderation/organizations/{id}/block' do
    path '/api/v1/moderation/organizations/{id}/block' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Block an organization (US-6.4, reason required)' do
        tags 'Moderation'
        description 'The organization and its events are hidden, ticket sales stop and its staff cannot create or ' \
                    'edit events. Sold tickets stay valid; nothing is deleted.'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body, schema: reason_body.merge(required: %w[reason])

        # The published event is created with the organization, so the spec needs no extra helper.
        let(:organization) do
          create(:organization, :with_owner).tap { |org| create(:event, :published, organization: org) }
        end
        let(:id) { organization.id }
        let(:decision) { { reason: 'Fraud' } }

        response '401', 'not authenticated' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { nil }

          run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
        end

        response '200', 'blocked; the owner is emailed' do
          schema organization_response

          context 'with a reason' do
            run_test! do
              expect(organization.reload).to have_attributes(status: 'blocked', block_reason: 'Fraud',
                                                             blocked_by_id: moderator.id)
            end
          end

          it 'emails the owner' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :organization_block_changed)
          end

          context 'with published events' do
            run_test!('hides the organization and its events and stops sales, keeping the data') do
              event = organization.reload.events.first
              expect(Organization.publicly_visible).not_to include(organization)
              expect(Event.publicly_visible).not_to include(event)
              expect(event).not_to be_ticket_sales_open
              expect(organization).not_to be_accepts_event_changes
              expect(event).to be_published
            end
          end
        end

        response '403', 'not a moderator' do
          let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

          run_test!
        end

        response '409', 'already blocked' do
          before { organization.update!(status: 'blocked', blocked_at: Time.current, block_reason: 'Spam') }

          run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
        end

        response '422', 'reason missing' do
          let(:decision) { {} }

          run_test! { expect(organization.reload).not_to be_blocked }
        end
      end
    end
  end

  describe '/api/v1/moderation/organizations/{id}/unblock' do
    path '/api/v1/moderation/organizations/{id}/unblock' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Unblock an organization' do
        tags 'Moderation'
        description 'Back to approved (or pending_approval if it was never approved); its open appeal is closed.'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body, required: false, schema: reason_body

        let(:organization) do
          create(:organization, :with_owner, :blocked).tap { |org| create(:event, :published, organization: org) }
        end
        let(:id) { organization.id }

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

        response '200', 'unblocked; the owner is emailed' do
          schema organization_response

          context 'with an approved organization' do
            run_test!('restores visibility and sales') do
              expect(organization.reload).to have_attributes(status: 'approved', blocked_at: nil, block_reason: nil)
              event = organization.events.first
              expect(Event.publicly_visible).to include(event)
              expect(event).to be_ticket_sales_open
              expect(ModerationLog.for_entity(organization).pluck(:decision)).to eq(%w[unblocked])
            end
          end

          it 'emails the owner' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :organization_block_changed)
          end

          context 'with an organization blocked before its approval' do
            let(:organization) { create(:organization, :pending, :blocked) }

            run_test! { expect(organization.reload).to be_pending_approval }
          end
        end

        response '409', 'not blocked' do
          schema '$ref' => '#/components/schemas/error'

          let(:organization) { create(:organization) }

          run_test! { expect(json['code']).to eq('NOT_BLOCKED') }
        end
      end
    end
  end
end
