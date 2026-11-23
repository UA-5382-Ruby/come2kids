# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TicketPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:ticket) { create(:ticket, user: user) }

  describe '#my?' do
    it 'allows an authenticated user' do
      expect(described_class.new(user, Ticket).my?).to be(true)
    end

    it 'denies a guest' do
      expect(described_class.new(nil, Ticket).my?).to be(false)
    end
  end

  describe '#show?' do
    it 'allows the ticket owner' do
      expect(described_class.new(user, ticket).show?).to be(true)
    end

    it 'denies another user' do
      expect(described_class.new(other_user, ticket).show?).to be(false)
    end
  end
end
