# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TicketMailer do
  let(:order) { create(:order, status: 'paid') }
  let(:outbox) do
    create(:email_outbox, template: 'ticket_purchase', to_email: order.user.email, payload: { 'order_id' => order.id })
  end

  before do
    order_item = create(:order_item, order: order)
    create(:ticket, order_item: order_item)
    create(:event_translation, event: order.event, title: 'Свято науки')
  end

  def html_body(mail)
    (mail.html_part || mail).body.decoded
  end

  it 'renders ukrainian body with order summary and pdf attachment' do
    mail = described_class.purchase_confirmation(outbox)
    expect(mail.subject).to eq('Ваші квитки на подію')
    expect(html_body(mail)).to include('Свято науки')
    expect(html_body(mail)).to include('Дякуємо за покупку')
    expect(mail.attachments.first.filename).to start_with('ticket-')
  end

  it 'renders english when the buyer prefers en' do
    order.user.update!(preferred_locale: 'en')
    create(:event_translation, :en, event: order.event, title: 'Science fair')
    mail = described_class.purchase_confirmation(outbox)
    expect(mail.subject).to eq('Your event tickets')
    expect(html_body(mail)).to include('Science fair')
  end
end
