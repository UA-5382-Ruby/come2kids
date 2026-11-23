# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Appeals::Decide do
  subject(:result) { described_class.call(appeal: appeal, moderator: moderator, decision: decision, reason: reason) }

  let(:moderator) { create(:user, :moderator) }
  let(:appeal) { create(:appeal) }
  let(:decision) { 'accepted' }
  let(:reason) { nil }

  it 'returns Success, accepts the appeal and unblocks the user in one transaction' do
    expect(result).to be_success
    expect(result.value!).to have_attributes(status: 'accepted', reviewed_by: moderator)
    expect(appeal.target.reload).not_to be_blocked
  end

  context 'when unblocking the target fails' do
    before { allow(Appeal).to receive(:close_open_for!).and_raise(ActiveRecord::StatementInvalid, 'boom') }

    it 'returns Failure and keeps both the appeal and the block unchanged' do
      expect { result }.not_to have_enqueued_mail(ModerationMailer, :appeal_decision)

      expect(result).to be_failure
      expect(appeal.reload).to be_open
      expect(appeal.target.reload).to be_blocked
    end
  end

  context 'when rejecting without a reason' do
    let(:decision) { 'rejected' }

    it 'returns Failure with VALIDATION_FAILED' do
      expect(result.failure.code).to eq('VALIDATION_FAILED')
      expect(appeal.reload).to be_open
    end
  end
end
