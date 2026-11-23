# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventRevision do
  let(:event) { create(:event) }

  it 'stores one pending revision' do
    revision = create(:event_revision, event: event)

    expect(revision).to be_pending
    expect(event.pending_revision).to eq(revision)
  end

  it 'rejects an unknown status' do
    revision = build(:event_revision, event: event, status: 'draft')

    expect(revision).not_to be_valid
    expect(revision.errors[:status]).to be_present
  end

  it 'allows only one pending revision per event' do
    create(:event_revision, event: event)

    expect { create(:event_revision, event: event) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows a new pending revision after the previous one is withdrawn' do
    create(:event_revision, event: event, status: 'withdrawn')

    expect(create(:event_revision, event: event)).to be_persisted
  end
end
