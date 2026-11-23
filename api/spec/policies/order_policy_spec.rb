# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:order) { create(:order, user: user) }

  describe '#my?' do
    it 'allows an authenticated user' do
      expect(described_class.new(user, Order).my?).to be(true)
    end

    it 'denies a guest' do
      expect(described_class.new(nil, Order).my?).to be(false)
    end
  end

  describe '#show?' do
    it 'allows the order owner' do
      expect(described_class.new(user, order).show?).to be(true)
    end

    it 'denies another user' do
      expect(described_class.new(other_user, order).show?).to be(false)
    end
  end
end
