# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tickets::RenderPdf do
  let(:ticket) { create(:ticket) }

  before { create(:event_translation, event: ticket.event, title: 'Майстер-клас з малювання') }

  def pdf_text(result)
    PDF::Reader.new(StringIO.new(result.value!)).pages.map(&:text).join
  end

  it 'returns a PDF with ticket data in Ukrainian by default' do
    result = described_class.call(ticket)
    expect(result).to be_success
    expect(result.value!.byteslice(0, 5)).to eq('%PDF-')
    text = pdf_text(result)
    expect(text).to include(ticket.code)
    expect(text).to include(ticket.user.first_name)
    expect(text).to include('Майстер-клас з малювання')
    expect(text).to include('Код квитка')
  end

  it 'renders English when user prefers en' do
    ticket.user.update!(preferred_locale: 'en')
    create(:event_translation, :en, event: ticket.event, title: 'Painting workshop')
    text = pdf_text(described_class.call(ticket))
    expect(text).to include('Painting workshop')
    expect(text).to include('Ticket code')
  end

  it 'falls back to Ukrainian title when en translation missing' do
    ticket.user.update!(preferred_locale: 'en')
    text = pdf_text(described_class.call(ticket))
    expect(text).to include('Майстер-клас з малювання')
  end

  it 'shows the online link for online events' do
    ticket.event.update!(location_type: 'online', online_url: 'https://meet.example.com/room')
    text = pdf_text(described_class.call(ticket))
    expect(text).to include('https://meet.example.com/room')
  end

  it 'includes ticket type and holder last name' do
    text = pdf_text(described_class.call(ticket))
    expect(text).to include(ticket.ticket_type.name)
    expect(text).to include(ticket.user.last_name)
  end
end
