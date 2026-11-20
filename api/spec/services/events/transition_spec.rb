# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Transition do
  let(:organization) { create(:organization) }
  let(:owner) { create(:company_member, :owner, organization: organization).user }
  let(:moderator) { create(:user, :moderator) }

  def draft_event
    create(:event, :draft, organization: organization, created_by: owner)
  end

  it 'records the initial draft when a draft is created' do
    result = Events::CreateDraft.call(organization: organization, author: owner, attributes: {})

    expect(result).to be_success
    history = result.value!.event_status_histories.sole
    expect(history.from_status).to be_nil
    expect(history.to_status).to eq('draft')
    expect(history.changed_by).to eq(owner)
  end

  it 'submits a draft for the organization owner' do
    event = draft_event

    result = described_class.call(event: event, to: 'under_review', actor: owner)

    expect(result).to be_success
    expect(event.reload.status).to eq('under_review')
    expect(event.submitted_at).to be_present
    expect(event.event_status_histories.sole).to have_attributes(from_status: 'draft', to_status: 'under_review')
  end

  it 'submits a rejected event' do
    event = create(:event, organization: organization, created_by: owner, status: 'rejected')

    result = described_class.call(event: event, to: 'under_review', actor: owner)

    expect(result).to be_success
    expect(event.reload.status).to eq('under_review')
  end

  it 'lets a moderator publish an event that is under review' do
    event = create(:event, organization: organization, status: 'under_review', rejection_reason: 'old')

    result = described_class.call(event: event, to: 'published', actor: moderator)

    expect(result).to be_success
    expect(event.reload).to have_attributes(status: 'published', reviewed_by: moderator, rejection_reason: nil)
    expect(event.published_at).to be_present
  end

  it 'lets a moderator reject an event when a reason is given' do
    event = create(:event, organization: organization, status: 'under_review')

    result = described_class.call(event: event, to: 'rejected', actor: moderator, reason: 'Немає адреси')

    expect(result).to be_success
    expect(event.reload).to have_attributes(status: 'rejected', rejection_reason: 'Немає адреси', reviewed_by: moderator)
  end

  it 'does not reject an event without a reason' do
    event = create(:event, organization: organization, status: 'under_review')

    result = described_class.call(event: event, to: 'rejected', actor: moderator)

    expect(result).to be_failure
    expect(event.reload.status).to eq('under_review')
    expect(event.event_status_histories).to be_empty
    expect(result.failure.errors[:reason]).to be_present
  end

  it 'does not let the owner publish' do
    event = create(:event, organization: organization, status: 'under_review', created_by: owner)

    result = described_class.call(event: event, to: 'published', actor: owner)

    expect(result).to be_failure
    expect(event.reload.status).to eq('under_review')
  end

  it 'does not skip from draft to published' do
    event = draft_event

    result = described_class.call(event: event, to: 'published', actor: moderator)

    expect(result).to be_failure
    expect(event.reload.status).to eq('draft')
    expect(result.failure.errors[:status]).to be_present
  end

  it 'lets an owner cancel a published event' do
    event = create(:event, organization: organization, created_by: owner, status: 'published')

    result = described_class.call(event: event, to: 'cancelled_by_organizer', actor: owner)

    expect(result).to be_success
    expect(event.reload.status).to eq('cancelled_by_organizer')
    expect(event.cancelled_at).to be_present
  end

  it 'does not let a stranger cancel a published event' do
    event = create(:event, organization: organization, status: 'published')

    result = described_class.call(event: event, to: 'cancelled_by_organizer', actor: create(:user))

    expect(result).to be_failure
    expect(event.reload.status).to eq('published')
  end
end
