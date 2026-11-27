# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Answer, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:answer)).to be_valid
    end

    it 'is invalid without text' do
      expect(build(:answer, text: '')).not_to be_valid
    end
  end
end
