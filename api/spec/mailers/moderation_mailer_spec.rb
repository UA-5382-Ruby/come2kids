# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ModerationMailer do
  let(:owner) { create(:user, preferred_locale: 'en', first_name: 'Olena') }
  let(:organization) { create(:organization) }

  before do
    create(:company_member, :owner, organization: organization, user: owner)
    organization.organization_translations.create!(locale: 'uk', name: 'Клуб')
    organization.organization_translations.create!(locale: 'en', name: 'Club')
  end

  it 'emails the owner about a rejected organization in their language, with the reason' do
    mail = described_class.organization_decision(organization, 'rejected', 'No contact details')

    expect(mail.to).to eq([ owner.email ])
    expect(mail.subject).to eq('Your organization "Club" was not approved')
    expect(mail.text_part.body.to_s).to include('Hello, Olena!', 'No contact details')
    expect(mail.html_part.body.to_s).to include('No contact details')
  end

  it 'uses Ukrainian for a Ukrainian-speaking recipient' do
    owner.update!(preferred_locale: 'uk')

    mail = described_class.organization_block_changed(organization, 'blocked', 'Шахрайство')

    expect(mail.subject).to eq('Вашу організацію «Клуб» заблоковано')
    expect(mail.text_part.body.to_s).to include('Шахрайство')
  end

  it 'emails the creator about an event decision with the localized title' do
    event = create(:event, :under_review, :with_translations, organization: organization, created_by: owner)

    mail = described_class.event_decision(event, 'approved')

    expect(mail.to).to eq([ owner.email ])
    expect(mail.subject).to eq('Your event "Programming camp" has been published')
    expect(mail.text_part.body.to_s).not_to include('Reason given by the moderator')
  end

  it 'emails a blocked user' do
    user = create(:user, :blocked, preferred_locale: 'en')

    mail = described_class.user_block_changed(user, 'blocked', 'Spam')

    expect(mail.subject).to eq('Your Come2Kids account has been blocked')
    expect(mail.text_part.body.to_s).to include('Spam')
  end

  context 'when the organization was never approved' do
    before { organization.update!(status: 'pending_approval', approved_at: nil) }

    it 'does not promise visible events after an unblock' do
      mail = described_class.organization_block_changed(organization, 'unblocked')

      expect(mail.text_part.body.to_s).to include('waiting for moderation again')
      expect(mail.text_part.body.to_s).not_to include('ticket sales')
    end

    it 'does not promise visible events after an accepted appeal' do
      appeal = create(:appeal, target: organization, submitted_by: owner, status: 'accepted')

      mail = described_class.appeal_decision(appeal)

      expect(mail.subject).to eq('Your appeal for "Club" has been accepted')
      expect(mail.text_part.body.to_s).to include('waiting for moderation again')
    end
  end

    it 'emails the appellant about the appeal decision' do
    appeal = create(:appeal, :rejected, target: organization, submitted_by: owner)

    mail = described_class.appeal_decision(appeal)

    expect(mail.to).to eq([ owner.email ])
    expect(mail.subject).to eq('Your appeal for "Club" has been rejected')
    expect(mail.text_part.body.to_s).to include('The block stays.')
  end
end
