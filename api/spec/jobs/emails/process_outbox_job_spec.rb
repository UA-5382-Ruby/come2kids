# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Emails::ProcessOutboxJob do
  let(:paid_order) { create(:order, status: 'paid') }
  let!(:ticket) do
    order_item = create(:order_item, order: paid_order)
    create(:ticket, order_item: order_item)
  end

  before { create(:event_translation, event: paid_order.event) }

  it 'enqueues and delivers the purchase email with pdf attachments' do
    expect { described_class.perform_now }.to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ paid_order.user.email ])
    expect(mail.attachments.map(&:filename)).to eq([ "ticket-#{ticket.code}.pdf" ])
    expect(mail.attachments.first.content_type).to include('application/pdf')
    expect(EmailOutbox.sole.status).to eq('sent')
  end

  it 'skips orders that are not paid' do
    paid_order.update!(status: 'pending')
    expect { described_class.perform_now }.not_to change { ActionMailer::Base.deliveries.size }
    expect(EmailOutbox.count).to eq(0)
  end

  it 'does not resend on the next run' do
    described_class.perform_now
    expect { described_class.perform_now }.not_to change { ActionMailer::Base.deliveries.size }
  end

  it 'marks the row failed and retries on the next run' do
    allow(TicketMailer).to receive(:purchase_confirmation).and_raise(StandardError, 'smtp down')
    described_class.perform_now
    row = EmailOutbox.sole
    expect(row.status).to eq('failed')
    expect(row.attempts).to eq(1)
    expect(row.last_error).to include('smtp down')

    allow(TicketMailer).to receive(:purchase_confirmation).and_call_original
    expect { described_class.perform_now }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(EmailOutbox.sole.status).to eq('sent')
  end
end
