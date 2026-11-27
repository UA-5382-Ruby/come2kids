# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::CancellationNoticeJob, type: :job do
  it 'queues cancellation emails for ticket holders and subscribers' do
    event = create(:event, status: 'cancelled_by_organizer', cancelled_at: Time.current)
    holder = create(:ticket, event: event).user
    subscriber = create(:subscription, target: event).user

    described_class.perform_now(event.id)

    expect(EmailOutbox.where(template: Subscriptions::Notifier::EVENT_CANCELLED).pluck(:to_email))
      .to contain_exactly(holder.email, subscriber.email)
  end

  it 'does nothing for a missing event' do
    expect { described_class.perform_now(0) }.not_to change(EmailOutbox, :count)
  end
end
