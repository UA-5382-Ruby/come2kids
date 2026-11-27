# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ModerationMailer, '#revision_decision' do
  let(:ticket) { create(:ticket) }
  let(:event) { ticket.event }
  let(:user) { create(:user) }
  let(:revision) { instance_double(EventRevision, submitted_by: user, event: event) }

  before { create(:event_translation, event: event, title: 'Свято науки') }

  it 'renders approval in ukrainian' do
    mail = described_class.revision_decision(revision, 'approved')
    expect(mail.subject).to eq('Зміни події «Свято науки» схвалено')
  end

  it 'renders rejection with the reason in english' do
    user.update!(preferred_locale: 'en')
    create(:event_translation, :en, event: event, title: 'Science fair')
    mail = described_class.revision_decision(revision, 'rejected', 'Incomplete description')
    expect(mail.subject).to eq('Changes to «Science fair» not approved')
    expect(mail.html_part.body.decoded).to include('Incomplete description')
  end
end
