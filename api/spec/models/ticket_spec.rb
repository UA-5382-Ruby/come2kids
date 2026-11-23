# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ticket, type: :model do
  describe 'defaults and validations' do
    it 'automatically generates code, qr_token, and issued_at on create' do
      ticket = create(:ticket, code: nil, qr_token: nil, issued_at: nil)

      expect(ticket).to be_persisted
      expect(ticket.code).to match(/\ATKT-[A-Z0-9]{10}\z/)
      expect(ticket.qr_token).to be_present
      expect(ticket.issued_at).to be_present
      expect(ticket).to be_status_valid
    end

    it 'enforces uniqueness of code and qr_token' do
      existing = create(:ticket)
      duplicate = build(:ticket, code: existing.code, qr_token: existing.qr_token)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to be_present
      expect(duplicate.errors[:qr_token]).to be_present
    end
  end
end
