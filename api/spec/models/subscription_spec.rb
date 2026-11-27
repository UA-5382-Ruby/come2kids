# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscription do
  it 'is unique per user and target' do
    existing = create(:subscription)
    duplicate = build(:subscription, user: existing.user, target: existing.target)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.of_kind?(:target_id, :taken)).to be(true)
  end

  it 'allows the same user to follow an event and an organization with the same id' do
    user = create(:user)
    event = create(:event)
    organization = Organization.find(event.organization_id)
    create(:subscription, user: user, target: event)

    expect(build(:subscription, user: user, target: organization)).to be_valid
  end

  it 'rejects other target types in the database' do
    subscription = create(:subscription)

    expect { subscription.update_column(:target_type, 'User') }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it 'returns the target name in the current locale' do
    event = create(:event, :with_translations)
    subscription = create(:subscription, target: event)

    I18n.with_locale(:en) { expect(subscription.target_name).to eq('Programming camp') }
  end
end
