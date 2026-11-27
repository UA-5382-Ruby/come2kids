# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tickets::CheckIn do
  let(:ticket) { create(:ticket) }
  let(:event) { ticket.event }
  let(:scanner) { create(:user) }

  before do
    create(:company_member, :owner, organization: event.organization, user: scanner)
  end

  def call(token: ticket.qr_token, user: scanner)
    described_class.call(event: event, token: token, user: user)
  end

  it 'marks the ticket used and records who scanned it' do
    result = call
    expect(result).to be_success
    ticket.reload
    expect(ticket.status).to eq('used')
    expect(ticket.used_at).to be_present
    expect(ticket.checked_in_by_id).to eq(scanner.id)
  end

  it 'rejects a second scan of the same ticket' do
    call
    result = call
    expect(result).to be_failure
    expect(result.failure.code).to eq(Api::ErrorCodes::CONFLICT)
  end

  it 'rejects a ticket used by another scanner after it was loaded' do
    ticket.update_columns(status: 'used', used_at: Time.current)
    expect(call).to be_failure
  end

  it 'rejects a blank token' do
    result = call(token: '')
    expect(result.failure.code).to eq(Api::ErrorCodes::BAD_REQUEST)
  end

  it 'rejects a ticket of another event' do
    other = create(:ticket)
    result = call(token: other.qr_token)
    expect(result.failure.code).to eq(Api::ErrorCodes::NOT_FOUND)
  end

  it 'rejects a cancelled ticket' do
    ticket.update_columns(status: 'cancelled')
    result = call
    expect(result.failure.code).to eq(Api::ErrorCodes::INVALID_STATUS_TRANSITION)
  end

  it 'rejects a cancelled event' do
    event.update_columns(status: 'cancelled_by_organizer')
    result = call
    expect(result.failure.code).to eq(Api::ErrorCodes::INVALID_STATUS_TRANSITION)
  end
end
