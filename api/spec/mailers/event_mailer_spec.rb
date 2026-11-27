# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventMailer do
  let(:ticket) { create(:ticket) }
  let(:event) { ticket.event }
  let(:user) { ticket.user }

  before { create(:event_translation, event: event, title: 'Свято науки') }

  it 'renders cancellation in ukrainian with the reason' do
    mail = described_class.cancelled(user, event, 'Захворів ведучий')
    expect(mail.subject).to eq('Подію «Свято науки» скасовано')
    expect(mail.html_part.body.decoded).to include('Захворів ведучий')
    expect(mail.text_part.body.decoded).to include('Захворів ведучий')
  end

  it 'renders cancellation in english when the recipient prefers en' do
    user.update!(preferred_locale: 'en')
    create(:event_translation, :en, event: event, title: 'Science fair')
    mail = described_class.cancelled(user, event)
    expect(mail.subject).to eq('Event «Science fair» cancelled')
  end

  it 'includes the change summary' do
    mail = described_class.changed(user, event, 'Початок перенесено на годину пізніше')
    expect(mail.html_part.body.decoded).to include('Початок перенесено на годину пізніше')
  end

  it 'names the organization in the publication email' do
    mail = described_class.published(user, event)
    expect(mail.subject).to include(event.organization.name)
    expect(mail.subject).to include('Свято науки')
  end

  it 'renders the reminder in ukrainian' do
    mail = described_class.reminder(user, event)
    expect(mail.subject).to eq('Нагадування: «Свято науки» вже завтра')
  end
end
