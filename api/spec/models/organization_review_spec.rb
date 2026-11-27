# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationReview, type: :model do
  describe 'validations' do
    subject(:review) { build(:organization_review) }

    it 'is valid with valid attributes' do
      expect(review).to be_valid
    end

    it 'is valid without text' do
      review.text = nil
      expect(review).to be_valid
    end

    it 'is invalid without rating' do
      review.rating = nil
      expect(review).not_to be_valid
    end

    it 'is invalid when rating is outside 1..5' do
      review.rating = 0
      expect(review).not_to be_valid

      review.rating = 6
      expect(review).not_to be_valid
    end

    it 'is invalid when user already reviewed the same organization' do
      existing = create(:organization_review)
      duplicate = build(:organization_review, organization: existing.organization, user: existing.user)

      expect(duplicate).not_to be_valid
    end
  end
end
