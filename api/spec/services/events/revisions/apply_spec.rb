# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Revisions::Apply do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:event) do
    create(:event, organization: organization, created_by: owner, status: 'published',
      location_type: 'offline', address: 'вул. Хрещатик, 1', city: 'Київ')
  end
  let!(:ticket_type) { create(:ticket_type, event: event, name: 'Дорослий', price: 100, total_quantity: 10, sold_quantity: 4) }
  let!(:kept_image) { create(:event_medium, event: event, kind: 'gallery', position: 0) }

  before { create(:event_translation, event: event, locale: 'uk', title: 'Майстерня') }

  def moderator
    @moderator ||= create(:user, :moderator)
  end

  def revision_for(city: 'Львів', start_at: event.start_at, end_at: event.end_at)
    Events::Revisions::Upsert.call(
      event: event, actor: owner,
      attributes: {
        city: city,
        start_at: start_at.utc.iso8601,
        end_at: end_at.utc.iso8601,
        ticket_types: [ {
          id: ticket_type.id, name: 'Дорослий', price: 250, total_quantity: 12
        } ],
        images: [ { id: kept_image.id, kind: 'gallery', position: 3 } ]
      }
    ).value!
  end

  it 'replaces the public event and keeps it published' do
    create(:event_medium, event: event, kind: 'gallery', position: 1)
    revision = revision_for

    result = described_class.call(revision: revision, reviewer: moderator)

    expect(result).to be_success
    expect(event.reload).to have_attributes(city: 'Львів', status: 'published')
    expect(ticket_type.reload).to have_attributes(price: 250, total_quantity: 12, sold_quantity: 4)
    expect(event.event_media.pluck(:id)).to eq([ kept_image.id ])
    expect(kept_image.reload.position).to eq(3)
    expect(revision.reload).to have_attributes(status: 'approved', reviewed_by: moderator)
  end

  it 'does not apply a revision that is not pending' do
    revision = revision_for
    revision.update!(status: 'withdrawn')

    result = described_class.call(revision: revision, reviewer: moderator)

    expect(result).to be_failure
    expect(event.reload.city).to eq('Київ')
  end

  it 'still approves when the start time changes and reminders are not stored yet' do
    later = event.start_at + 1.day
    revision = revision_for(start_at: later, end_at: later + 2.hours)

    expect(described_class.call(revision: revision, reviewer: moderator)).to be_success
    expect(event.reload.start_at).to be_within(1.second).of(later)
  end
end
