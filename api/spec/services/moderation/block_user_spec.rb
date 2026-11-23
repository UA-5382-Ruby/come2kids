# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Moderation::BlockUser do
  subject(:result) { described_class.call(user: user, moderator: moderator, reason: reason) }

  let(:moderator) { create(:user, :moderator) }
  let(:user) { create(:user) }
  let(:reason) { 'Spam' }

  context 'when the user can be blocked' do
    it 'returns Success with the blocked user' do
      expect(result).to be_success
      expect(result.value!).to eq(user)
      expect(user.reload).to have_attributes(block_reason: 'Spam', blocked_by_id: moderator.id)
    end

    it 'writes the moderation log and schedules the email and the activity log' do
      expect { result }.to change(ModerationLog, :count).by(1)
        .and have_enqueued_mail(ModerationMailer, :user_block_changed)
        .and have_enqueued_job(ActivityLogJob)
    end
  end

  context 'without a reason' do
    let(:reason) { '' }

    it 'returns Failure with VALIDATION_FAILED and changes nothing' do
      expect(result).to be_failure
      expect(result.failure).to be_a(Api::ApplicationError)
      expect(result.failure.code).to eq('VALIDATION_FAILED')
      expect(user.reload).not_to be_blocked
    end
  end

  context 'when the user is a moderator' do
    let(:user) { create(:user, :moderator) }

    it 'returns Failure with CANNOT_BLOCK_MODERATOR and sends no email' do
      expect { result }.not_to have_enqueued_mail(ModerationMailer, :user_block_changed)

      expect(result.failure.code).to eq('CANNOT_BLOCK_MODERATOR')
    end
  end

  context 'when the database write fails' do
    before { allow(ModerationLog).to receive(:record!).and_raise(ActiveRecord::StatementInvalid, 'boom') }

    it 'returns Failure, rolls the block back and notifies nobody' do
      expect { result }.not_to have_enqueued_mail(ModerationMailer, :user_block_changed)

      expect(result.failure).to be_a(ActiveRecord::StatementInvalid)
      expect(user.reload).not_to be_blocked
    end
  end

  context 'when scheduling the email fails after the commit' do
    before do
      allow(ModerationMailer).to receive(:user_block_changed).and_raise(StandardError, 'queue is down')
    end

    it 'still returns Success because the block is saved' do
      expect(result).to be_success
      expect(user.reload).to be_blocked
    end
  end
end
