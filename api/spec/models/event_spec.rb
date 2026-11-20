# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event do
  it 'accepts cancelled_by_organizer' do
    event = build(:event, status: 'cancelled_by_organizer')

    expect(event).to be_valid
  end

  it 'rejects an unknown status' do
    event = build(:event, status: 'pending')

    expect(event).not_to be_valid
    expect(event.errors[:status]).to be_present
  end
end
