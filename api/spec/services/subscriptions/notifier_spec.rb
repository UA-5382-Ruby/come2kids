# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::Notifier do
  let(:organization) { create(:organization) }
  let(:event) { create(:event, :published, organization: organization) }

  def holder_of(event, user = create(:user))
    create(:ticket, user: user, event: event)
    user
  end

  describe '.new_event' do
    it 'queues one email per organization subscriber' do
      subscription = create(:subscription, target: organization)
      create(:subscription, target: event) # event subscribers are not told about new events

      described_class.new_event(event)

      row = EmailOutbox.sole
      expect(row).to have_attributes(template: described_class::NEW_EVENT, to_email: subscription.user.email)
      expect(row.payload).to include('event_id' => event.id, 'user_id' => subscription.user_id,
                                     'subscription_id' => subscription.id)
    end

    it 'skips blocked, deactivated and deleted users' do
      create(:subscription, target: organization, user: create(:user, :blocked))
      create(:subscription, target: organization, user: create(:user, is_active: false))
      create(:subscription, target: organization, user: create(:user, :deleted))

      described_class.new_event(event)

      expect(EmailOutbox.count).to eq(0)
    end

    it 'does not queue a second email for the same event' do
      create(:subscription, target: organization)

      2.times { described_class.new_event(event) }

      expect(EmailOutbox.count).to eq(1)
    end

    it 'sends nothing while the event is not public' do
      create(:subscription, target: organization)
      event.update!(status: 'under_review')

      described_class.new_event(event)

      expect(EmailOutbox.count).to eq(0)
    end

    it 'writes large audiences in batches' do
      stub_const('Subscriptions::Enqueue::BATCH_SIZE', 2)
      create_list(:subscription, 5, target: organization)
      allow(EmailOutbox).to receive(:insert_all).and_call_original

      described_class.new_event(event)

      expect(EmailOutbox).to have_received(:insert_all).exactly(3).times
      expect(EmailOutbox.count).to eq(5)
    end
  end

  describe '.event_changed' do
    let(:changes) { { 'location' => { 'from' => { 'city' => 'Kyiv' }, 'to' => { 'city' => 'Lviv' } } } }

    it 'queues one email for a user who both follows the event and holds a ticket' do
      both = holder_of(event)
      create(:subscription, target: event, user: both)
      holder = holder_of(event)
      subscriber = create(:subscription, target: event).user
      create(:subscription, target: organization) # organization subscribers are not included

      described_class.event_changed(event, revision_id: 7, changes: changes)

      expect(EmailOutbox.pluck(:to_email)).to contain_exactly(both.email, holder.email, subscriber.email)
      expect(EmailOutbox.find_by(to_email: holder.email).payload).not_to have_key('subscription_id')
    end

    it 'ignores holders of cancelled tickets' do
      user = create(:user)
      create(:ticket, user: user, event: event, status: 'cancelled')

      described_class.event_changed(event, revision_id: 7, changes: changes)

      expect(EmailOutbox.count).to eq(0)
    end

    it 'sends nothing without changes' do
      create(:subscription, target: event)

      described_class.event_changed(event, revision_id: 7, changes: {})

      expect(EmailOutbox.count).to eq(0)
    end
  end

  describe '.organization_updated' do
    it 'queues every separate edit once' do
      create(:subscription, target: organization)

      described_class.organization_updated(organization, version: '1')
      described_class.organization_updated(organization, version: '1')
      described_class.organization_updated(organization, version: '2')

      expect(EmailOutbox.count).to eq(2)
    end
  end

  describe '.event_cancelled' do
    it 'notifies holders and subscribers of a cancelled event' do
      holder = holder_of(event)
      event.update!(status: 'cancelled_by_organizer', cancelled_at: Time.current)

      described_class.event_cancelled(event)

      expect(EmailOutbox.sole).to have_attributes(to_email: holder.email, template: described_class::EVENT_CANCELLED)
    end
  end
end
