# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Answers::CreateService do
  let(:organization) { create(:organization, :with_owner) }
  let(:event) { create(:event, organization: organization, status: :published) }
  let(:regular_user) { create(:user) }
  let(:moderator) { create(:user, :moderator) }

  describe '#call' do
    context 'when answering an event question' do
      let(:question) { create(:question, target: event) }

      it 'allows organization owner to answer and enqueues email' do
        expect do
          result = described_class.call(author: organization.owner, question: question, text: 'Yes, parking is free.')
          expect(result).to be_success
        end.to have_enqueued_mail(QuestionMailer, :answer_received)
      end

      it 'forbids regular user' do
        result = described_class.call(author: regular_user, question: question, text: 'Test')
        expect(result).to be_failure
        expect(result.failure.code).to eq(Api::ErrorCodes::FORBIDDEN)
      end

      it 'forbids moderator for event questions' do
        result = described_class.call(author: moderator, question: question, text: 'Test')
        expect(result).to be_failure
        expect(result.failure.code).to eq(Api::ErrorCodes::FORBIDDEN)
      end
    end

    context 'when answering a platform question' do
      let(:question) { create(:question, :for_platform) }

      it 'allows moderator to answer' do
        result = described_class.call(author: moderator, question: question, text: 'Support answer.')
        expect(result).to be_success
      end

      it 'forbids organization owner' do
        result = described_class.call(author: organization.owner, question: question, text: 'Test')
        expect(result).to be_failure
        expect(result.failure.code).to eq(Api::ErrorCodes::FORBIDDEN)
      end
    end
  end
end
