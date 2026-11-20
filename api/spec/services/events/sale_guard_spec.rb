# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::SaleGuard do
  it 'allows a published event that has not been deleted' do
    event = build(:event, status: 'published', deleted_at: nil)

    expect(described_class.open?(event)).to be(true)
  end

  it 'refuses a cancelled event' do
    event = build(:event, status: 'cancelled_by_organizer')

    expect(described_class.open?(event)).to be(false)
  end

  it 'refuses a published event that was soft-deleted' do
    event = build(:event, status: 'published', deleted_at: Time.current)

    expect(described_class.open?(event)).to be(false)
  end

  it 'refuses a draft' do
    event = build(:event, :draft)

    expect(described_class.open?(event)).to be(false)
  end
end
