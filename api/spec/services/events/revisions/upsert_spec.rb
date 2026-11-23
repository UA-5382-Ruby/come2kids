# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Revisions::Upsert do
  subject(:result) { described_class.call(event: event, actor: owner, attributes: attributes) }

  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:event) do
    create(:event, organization: organization, created_by: owner, status: 'published',
      location_type: 'offline', address: 'вул. Хрещатик, 1', city: 'Київ')
  end
  let(:attributes) { { city: 'Львів' } }
  let!(:ticket_type) { create(:ticket_type, event: event, name: 'Дорослий', total_quantity: 10, price: 100) }

  before { create(:event_translation, event: event, locale: 'uk', title: 'Майстерня') }

  it 'stores a revision and leaves the public event unchanged' do
    expect(result).to be_success
    expect(event.reload.city).to eq('Київ')
    expect(result.value!.payload['city']).to eq('Львів')
    expect(result.value!).to be_pending
  end

  it 'updates the existing pending revision' do
    first = result.value!
    second = described_class.call(event: event, actor: owner, attributes: { city: 'Одеса' }).value!

    expect(second.id).to eq(first.id)
    expect(event.event_revisions.pending.count).to eq(1)
    expect(second.payload['city']).to eq('Одеса')
  end

  it 'rejects an image that is not attached to the event' do
    outcome = described_class.call(event: event, actor: owner, attributes: { images: [ { id: 0, kind: 'gallery' } ] })

    expect(outcome).to be_failure
    expect(event.reload.pending_revision).to be_nil
  end

  it 'rejects a quantity below tickets already held' do
    allow(Events::TicketDemand).to receive(:for).with(ticket_type.id).and_return(8)
    outcome = described_class.call(event: event, actor: owner, attributes: {
      ticket_types: [ { id: ticket_type.id, name: ticket_type.name, price: 50, total_quantity: 3 } ]
    })

    expect(outcome).to be_failure
    expect(outcome.failure.errors.map(&:attribute).map(&:to_s)).to include('ticket_types[0].total_quantity')
  end

  it 'rejects removing a ticket type that still has demand' do
    allow(Events::TicketDemand).to receive(:for).and_return(2)
    outcome = described_class.call(event: event, actor: owner, attributes: {
      ticket_types: [ { name: 'Новий', price: 0, total_quantity: 5 } ]
    })

    expect(outcome).to be_failure
    expect(outcome.failure.errors[:ticket_types]).to be_present
  end

  it 'withdraws the pending revision' do
    result
    withdrawn = Events::Revisions::Withdraw.call(event: event)

    expect(withdrawn).to be_success
    expect(withdrawn.value!.status).to eq('withdrawn')
    expect(event.reload.pending_revision).to be_nil
  end
end
