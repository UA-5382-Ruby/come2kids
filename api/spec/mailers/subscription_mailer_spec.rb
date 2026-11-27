# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubscriptionMailer do
  let(:organization) { create(:organization) }
  let(:event) do
    create(:event, :published, :with_translations, organization: organization,
                                                   address: 'Khreshchatyk 1', city: 'Kyiv', time_zone: 'Europe/Kyiv')
  end
  let(:user) { create(:user, preferred_locale: 'en') }

  def outbox(template, payload)
    build(:email_outbox, template: template, to_email: user.email, payload: payload.merge('user_id' => user.id))
  end

  describe '#new_event' do
    let(:subscription) { create(:subscription, user: user, target: organization) }

    it 'renders in the recipient language with event and unsubscribe links' do
      mail = described_class.new_event(outbox('subscription_new_event', 'event_id' => event.id,
                                                                        'subscription_id' => subscription.id))

      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include('Programming camp')
      body = mail.text_part.decoded
      expect(body).to include("/events/#{event.id}")
      expect(body).to include('/unsubscribe?token=')
    end

    it 'renders Ukrainian for a Ukrainian user' do
      user.update!(preferred_locale: 'uk')

      mail = described_class.new_event(outbox('subscription_new_event', 'event_id' => event.id,
                                                                        'subscription_id' => subscription.id))

      expect(mail.subject).to include('Табір програмування')
    end

    it 'sends nothing when the user has unsubscribed since' do
      payload = { 'event_id' => event.id, 'subscription_id' => subscription.id }
      subscription.destroy!

      expect(described_class.new_event(outbox('subscription_new_event', payload)).message)
        .to be_a(ActionMailer::Base::NullMail)
    end

    it 'sends nothing to a user blocked since' do
      user.update!(blocked_at: Time.current, block_reason: 'Spam')

      mail = described_class.new_event(outbox('subscription_new_event', 'event_id' => event.id,
                                                                        'subscription_id' => subscription.id))

      expect(mail.message).to be_a(ActionMailer::Base::NullMail)
    end
  end

  describe '#event_changed' do
    it 'lists the changes and links a ticket holder to their tickets without an unsubscribe link' do
      create(:ticket, user: user, event: event)
      changes = {
        'location' => { 'from' => { 'location_type' => 'offline', 'address' => 'Old 1', 'city' => 'Kyiv' },
                        'to' => { 'location_type' => 'offline', 'address' => 'New 2', 'city' => 'Lviv' } },
        'prices' => { 'from' => { 'Adult' => 10_000 }, 'to' => { 'Adult' => 15_000 } }
      }

      mail = described_class.event_changed(outbox('subscription_event_changed', 'event_id' => event.id,
                                                                                'changes' => changes))

      body = mail.text_part.decoded
      expect(body).to include('Location: Old 1, Kyiv → New 2, Lviv')
      expect(body).to include('Price of "Adult": 100.00 UAH → 150.00 UAH')
      expect(body).to include('/tickets')
      expect(body).not_to include('/unsubscribe')
    end

    it 'sends nothing to a user who neither follows the event nor holds a ticket' do
      mail = described_class.event_changed(outbox('subscription_event_changed', 'event_id' => event.id,
                                                                                'changes' => {}))

      expect(mail.message).to be_a(ActionMailer::Base::NullMail)
    end
  end

  describe '#event_reminder' do
    let(:subscription) { create(:subscription, user: user, target: event) }

    def reminder_payload
      { 'event_id' => event.id, 'start_at' => event.start_at.utc.iso8601, 'subscription_id' => subscription.id }
    end

    it 'contains the title, time in the event time zone, location and the event link' do
      create(:event_reminder, event: event, user: user)

      mail = described_class.event_reminder(outbox('event_reminder', reminder_payload))

      body = mail.text_part.decoded
      expect(mail.subject).to include('Programming camp')
      expect(body).to include('Europe/Kyiv')
      expect(body).to include('Khreshchatyk 1, Kyiv')
      expect(body).to include("/events/#{event.id}")
    end

    it 'does not send a reminder made for an old start time' do
      create(:event_reminder, event: event, user: user)
      payload = reminder_payload
      event.update!(start_at: event.start_at + 1.day, end_at: event.end_at + 1.day)

      expect(described_class.event_reminder(outbox('event_reminder', payload)).message)
        .to be_a(ActionMailer::Base::NullMail)
    end
  end
end
