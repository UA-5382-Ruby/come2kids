# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::IssuedTickets do
  it 'counts no issued tickets while the tickets table is absent' do
    event = create(:event)
    create(:ticket_type, event: event)

    expect(described_class.for(event)).to eq(0)
  end

  it 'adds issued rows once the tickets table exists' do
    event = create(:event)
    ticket_type = create(:ticket_type, event: event)
    allow(Events::TicketDemand).to receive(:issued).with(ticket_type.id).and_return(2)

    expect(described_class.for(event.reload)).to eq(2)
  end
end
