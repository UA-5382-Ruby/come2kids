# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tickets::CheckInStatistics do
  let(:ticket) { create(:ticket) }
  let(:event) { ticket.event }

  def stats
    described_class.call(event: event).value!
  end

  it 'counts a freshly issued ticket as remaining' do
    expect(stats.issued).to eq(1)
    expect(stats.remaining).to eq(1)
    expect(stats.checked_in).to eq(0)
    expect(stats.attendance_rate).to eq(0.0)
  end

  it 'counts used and cancelled tickets' do
    ticket.update_columns(status: 'used', used_at: Time.current)
    create(:ticket, event: event, status: 'cancelled')
    expect(stats.issued).to eq(2)
    expect(stats.checked_in).to eq(1)
    expect(stats.cancelled).to eq(1)
    expect(stats.attendance_rate).to eq(50.0)
  end

  it 'breaks the counts down by ticket type' do
    ticket.update_columns(status: 'used', used_at: Time.current)
    row = stats.by_ticket_type.first
    expect(row[:ticket_type_id]).to eq(ticket.ticket_type.id)
    expect(row[:issued]).to eq(1)
    expect(row[:checked_in]).to eq(1)
  end

  it 'returns zeros for an event without tickets' do
    summary = described_class.call(event: create(:event)).value!
    expect(summary.issued).to eq(0)
    expect(summary.attendance_rate).to eq(0.0)
    expect(summary.by_ticket_type).to eq([])
  end
end
