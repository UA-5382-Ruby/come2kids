# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventStatusHistory do
  let(:event) { create(:event, :draft) }

  it 'records a first transition without a previous status' do
    history = event.event_status_histories.create!(
      to_status: 'draft',
      changed_by: event.created_by,
      changed_at: Time.current
    )

    expect(history.from_status).to be_nil
    expect(history.to_status).to eq('draft')
  end

  it 'rejects an unknown target status' do
    history = event.event_status_histories.build(to_status: 'pending', changed_at: Time.current)

    expect(history).not_to be_valid
    expect(history.errors[:to_status]).to be_present
  end

  it 'rejects an unknown previous status' do
    history = event.event_status_histories.build(
      from_status: 'failed',
      to_status: 'draft',
      changed_at: Time.current
    )

    expect(history).not_to be_valid
    expect(history.errors[:from_status]).to be_present
  end
end
