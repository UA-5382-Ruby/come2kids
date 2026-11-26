# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Questions::HideService do
  let(:organization) { create(:organization, :with_owner) }
  let(:event) { create(:event, organization: organization, status: :published) }
  let(:question) { create(:question, target: event) }
  let(:moderator) { create(:user, :moderator) }
  let(:regular_user) { create(:user) }

  it 'allows owner to hide question' do
    result = described_class.call(actor: organization.owner, question: question)
    expect(result).to be_success
    expect(question.reload.is_hidden).to be(true)
  end

  it 'allows moderator to hide any question' do
    result = described_class.call(actor: moderator, question: question)
    expect(result).to be_success
    expect(question.reload.is_hidden).to be(true)
  end

  it 'forbids regular user' do
    result = described_class.call(actor: regular_user, question: question)
    expect(result).to be_failure
    expect(result.failure.code).to eq(Api::ErrorCodes::FORBIDDEN)
  end
end
