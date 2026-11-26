# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Question, type: :model do
  describe 'validations' do
    it 'is valid for an event target' do
      expect(build(:question)).to be_valid
    end

    it 'is valid for an organization target' do
      expect(build(:question, :for_organization)).to be_valid
    end

    it 'is valid for a platform target without target_id' do
      expect(build(:question, :for_platform)).to be_valid
    end

    it 'is invalid with an unknown target_type' do
      question = build(:question, target_type: 'Ticket')
      expect(question).not_to be_valid
    end

    it 'is invalid when platform question has target_id' do
      question = build(:question, :for_platform, target_id: 1)
      expect(question).not_to be_valid
    end

    it 'is invalid without text' do
      question = build(:question, text: '')
      expect(question).not_to be_valid
    end
  end

  describe '.visible' do
    it 'excludes hidden questions' do
      visible = create(:question)
      create(:question, :hidden)

      expect(described_class.visible).to eq([ visible ])
    end
  end
end
