# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::SendReminders do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.parse('2026-12-01 10:00:00') }
  let(:organization) { create(:organization) }
  let(:event) do
    create(:event, :published, organization: organization, start_at: now + 20.hours, end_at: now + 22.hours)
  end

  before { travel_to(now) }
  after { travel_back }

  def holder_of(event, user = create(:user))
    create(:ticket, user: user, event: event)
    user
  end

  it 'queues one reminder for subscribers and ticket holders, once per user' do
    both = holder_of(event)
    create(:subscription, target: event, user: both)
    subscriber = create(:subscription, target: event).user
    holder = holder_of(event)

    expect(described_class.call).to eq(3)

    expect(EmailOutbox.where(template: 'event_reminder').pluck(:to_email))
      .to contain_exactly(both.email, subscriber.email, holder.email)
    expect(EventReminder.where(event: event).pluck(:user_id)).to contain_exactly(both.id, subscriber.id, holder.id)
  end

  it 'does not remind organization subscribers' do
    create(:subscription, target: organization)

    expect(described_class.call).to eq(0)
  end

  it 'does not send duplicates on the next run' do
    holder_of(event)
    described_class.call

    travel 1.hour
    expect(described_class.call).to eq(0)
    expect(EmailOutbox.count).to eq(1)
  end

  it 'skips events starting later than 24 hours from now' do
    event.update!(start_at: now + 25.hours, end_at: now + 26.hours)
    holder_of(event)

    expect(described_class.call).to eq(0)

    travel 2.hours
    expect(described_class.call).to eq(1)
  end

  it 'skips events that already started' do
    event.update_columns(start_at: now - 1.hour, end_at: now + 1.hour)
    holder_of(event)

    expect(described_class.call).to eq(0)
  end

  it 'reminds about an event approved less than 24 hours before the start on the next run' do
    event.update!(status: 'under_review')
    holder_of(event)
    expect(described_class.call).to eq(0)

    event.update!(status: 'published')
    expect(described_class.call).to eq(1)
  end

  it 'skips cancelled events and events of a blocked organization' do
    holder_of(event)
    event.update!(status: 'cancelled_by_organizer', cancelled_at: now)
    blocked_event = create(:event, :published, organization: create(:organization, :blocked),
                                               start_at: now + 2.hours, end_at: now + 3.hours)
    holder_of(blocked_event)

    expect(described_class.call).to eq(0)
  end

  it 'skips blocked users' do
    holder_of(event, create(:user, :blocked))

    expect(described_class.call).to eq(0)
  end

  it 'sends a new reminder after the start time changes' do
    holder_of(event)
    described_class.call

    event.update!(start_at: now + 23.hours, end_at: now + 24.hours)
    Events::ClearReminders.call(event)

    expect(described_class.call).to eq(1)
    expect(EmailOutbox.count).to eq(2)
  end
end
