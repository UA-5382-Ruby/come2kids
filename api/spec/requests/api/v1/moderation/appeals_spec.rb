# frozen_string_literal: true

require 'swagger_helper'

RSpec::Matchers.define_negated_matcher :not_have_enqueued_mail, :have_enqueued_mail

RSpec.describe 'Moderation: appeals and log', type: :request do
  let(:moderator) { create(:user, :moderator) }
  let(:authorization) { "Bearer #{JwtService.encode(moderator)}" }

  appeal_response = {
    type: :object, properties: { data: { '$ref' => '#/components/schemas/appeal' } }, required: %w[data]
  }

  describe '/api/v1/moderation/appeals' do
    path '/api/v1/moderation/appeals' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization

      get 'Appeal queue (US-6.5)' do
        tags 'Moderation'
        description 'Users and organizations, with the target, its block reason and blocked_by_id, so that ' \
                    'another moderator than the one who blocked can decide (FR-APP-5).'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :status, in: :query, type: :string, required: false,
                  description: 'open (default), accepted, rejected or all'
        parameter name: :target_type, in: :query, type: :string, required: false, enum: Appeal::TARGET_TYPES
        parameter name: :page, in: :query, type: :integer, required: false
        parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size

        let!(:open_appeal) { create(:appeal) }

        before { create(:appeal, :rejected) }

        response '200', 'open appeals' do
          schema type: :object,
                 properties: {
                   data: { type: :array, items: { '$ref' => '#/components/schemas/appeal' } },
                   pagination: { '$ref' => '#/components/schemas/pagination' }
                 },
                 required: %w[data pagination]

          run_test! do
            expect(json['data'].pluck('id')).to eq([ open_appeal.id ])
            expect(json['data'].first['target']).to include('id' => open_appeal.target_id, 'blocked' => true)
            expect(json['data'].first['target']).to have_key('blocked_by_id')
          end
        end

        response '401', 'not authenticated' do
          let(:authorization) { nil }

          run_test!
        end

        response '403', 'not a moderator' do
          let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

          run_test!
        end
      end
    end
  end

  describe '/api/v1/moderation/appeals/{id}' do
    path '/api/v1/moderation/appeals/{id}' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      get 'Show one appeal' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]

        let(:appeal) { create(:appeal) }
        let(:id) { appeal.id }

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

        response '200', 'appeal' do
          schema appeal_response

          run_test! { expect(json['data']).to include('id' => appeal.id, 'status' => 'open') }
        end

        response '404', 'appeal not found' do
          let(:id) { 0 }

          run_test!
        end
      end
    end
  end

  describe '/api/v1/moderation/appeals/{id}/accept' do
    path '/api/v1/moderation/appeals/{id}/accept' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Accept an appeal: unblock the user or restore the organization' do
        tags 'Moderation'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body, required: false,
                  schema: { type: :object, properties: { reason: { type: :string } } }

        let(:appeal) { create(:appeal) }
        let(:id) { appeal.id }

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

        response '200', 'accepted; the appellant gets one decision email' do
          schema appeal_response

          context 'with a blocked user' do
            run_test! do
              expect(appeal.reload).to have_attributes(status: 'accepted', reviewed_by_id: moderator.id)
              expect(appeal.target.reload).not_to be_blocked
              expect(ModerationLog.for_entity(appeal).pluck(:decision)).to include('appeal_accepted')
            end
          end

          it 'sends the appeal decision and no separate unblock email' do
            expect { send_documented_request }
              .to have_enqueued_mail(ModerationMailer, :appeal_decision)
              .and(not_have_enqueued_mail(ModerationMailer, :user_block_changed))
          end

          context 'with a blocked organization' do
            let(:organization) { create(:organization, :blocked) }
            let(:appeal) do
              create(:appeal, target: organization,
                              submitted_by: create(:company_member, :owner, organization: organization).user)
            end

            run_test!('restores the organization to approved') { expect(organization.reload).to be_approved }
          end
        end

        response '409', 'appeal already decided' do
          let(:appeal) { create(:appeal, :rejected) }

          run_test! { expect(json['code']).to eq('INVALID_STATUS_TRANSITION') }
        end
      end
    end
  end

  describe '/api/v1/moderation/appeals/{id}/reject' do
    path '/api/v1/moderation/appeals/{id}/reject' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization
      parameter name: :id, in: :path, type: :integer

      post 'Reject an appeal (reason required); a new appeal is possible 24 hours later' do
        tags 'Moderation'
        consumes 'application/json'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :decision, in: :body,
                  schema: { type: :object, properties: { reason: { type: :string } }, required: %w[reason] }

        let(:appeal) { create(:appeal) }
        let(:id) { appeal.id }
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

        response '200', 'rejected; the block stays and the appellant is notified' do
          schema appeal_response

          let(:decision) { { reason: 'Repeated spam' } }

          context 'with a reason' do
            run_test! do
              expect(appeal.reload).to have_attributes(status: 'rejected', decision_reason: 'Repeated spam')
              expect(appeal.target.reload).to be_blocked
            end
          end

          it 'notifies the appellant' do
            expect { send_documented_request }.to have_enqueued_mail(ModerationMailer, :appeal_decision)
          end
        end

        response '422', 'reason missing' do
          schema '$ref' => '#/components/schemas/error'

          run_test! { expect(appeal.reload).to be_open }
        end
      end
    end
  end

  describe '/api/v1/moderation/logs' do
    path '/api/v1/moderation/logs' do
      parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization

      get 'Moderation decisions (FR-MOD-3): who, when, what and why' do
        tags 'Moderation'
        produces 'application/json'
        security [ bearerAuth: [] ]
        parameter name: :entity_type, in: :query, type: :string, required: false, enum: ModerationLog::ENTITY_TYPES
        parameter name: :entity_id, in: :query, type: :integer, required: false
        parameter name: :moderator_id, in: :query, type: :integer, required: false
        parameter name: :decision, in: :query, type: :string, required: false, enum: ModerationLog::DECISIONS
        parameter name: :page, in: :query, type: :integer, required: false
        parameter name: :pageSize, in: :query, type: :integer, required: false, getter: :page_size

        let(:blocked_user) { create(:user) }

        before do
          ModerationLog.record!(entity: blocked_user, moderator: moderator, decision: :blocked, reason: 'Spam')
          ModerationLog.record!(entity: create(:organization), moderator: moderator, decision: :approved)
        end

        response '401', 'not authenticated' do
          schema '$ref' => '#/components/schemas/error'

          let(:authorization) { nil }

          run_test! { expect(json['code']).to eq('UNAUTHORIZED') }
        end

        response '200', 'decisions' do
          schema type: :object,
                 properties: {
                   data: { type: :array, items: { '$ref' => '#/components/schemas/moderation_log' } },
                   pagination: { '$ref' => '#/components/schemas/pagination' }
                 },
                 required: %w[data pagination]

          let(:entity_type) { 'User' }
          let(:entity_id) { blocked_user.id }

          run_test!('filters by entity') do
            expect(json['data'].map { |log| log.slice('decision', 'reason', 'moderator_id') })
              .to eq([ { 'decision' => 'blocked', 'reason' => 'Spam', 'moderator_id' => moderator.id } ])
          end
        end

        response '403', 'not readable by other roles' do
          let(:authorization) { "Bearer #{JwtService.encode(create(:user))}" }

          run_test!
        end
      end
    end
  end
end
