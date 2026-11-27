# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Update do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, city: 'Kyiv') }
  let(:user) { create(:user) }

  before { organization.organization_translations.create!(locale: 'uk', name: 'Стара назва') }

  it 'saves a changed name of an existing translation' do
    I18n.with_locale(:uk) { described_class.call(organization: organization, user: user, name: 'Нова назва') }

    expect(organization.organization_translations.find_by(locale: 'uk').name).to eq('Нова назва')
  end

  it 'notifies subscribers when public information changes (FR-SUB-2)' do
    expect do
      I18n.with_locale(:uk) { described_class.call(organization: organization, user: user, city: 'Lviv') }
    end.to have_enqueued_job(Subscriptions::NotifyJob).with('organization_updated', organization.id, hash_including('version'))
  end

  it 'does not notify when nothing changed' do
    expect do
      I18n.with_locale(:uk) { described_class.call(organization: organization, user: user, city: 'Kyiv') }
    end.not_to have_enqueued_job(Subscriptions::NotifyJob)
  end

  it 'does not notify while the organization is not approved' do
    organization.update!(status: 'pending_approval', approved_at: nil)

    expect do
      I18n.with_locale(:uk) { described_class.call(organization: organization, user: user, city: 'Lviv') }
    end.not_to have_enqueued_job(Subscriptions::NotifyJob)
  end
end
