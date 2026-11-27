# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationReviews::CreateService do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:past_event) { create(:event, :past, organization: organization) }

  describe '#call' do
    it 'creates a review when user has a valid ticket for a past event of the organization' do
      create(:ticket, user: user, event: past_event, status: 'valid')

      review = described_class.new(
        user: user,
        organization: organization,
        rating: 5,
        text: 'Чудова організація!'
      ).call

      expect(review).to be_persisted
      expect(review.rating).to eq(5)
      expect(review.text).to eq('Чудова організація!')
    end

    it 'creates a review when user has a used ticket for a past event of the organization' do
      create(:ticket, user: user, event: past_event, status: 'used')

      review = described_class.new(user: user, organization: organization, rating: 4).call

      expect(review).to be_persisted
      expect(review.rating).to eq(4)
    end

    it 'raises AttendanceRequiredError when user has no tickets for the organization' do
      expect do
        described_class.new(user: user, organization: organization, rating: 5).call
      end.to raise_error(described_class::AttendanceRequiredError)
    end

    it 'raises AttendanceRequiredError when user only has a ticket for a future event' do
      future_event = create(:event, organization: organization)
      create(:ticket, user: user, event: future_event, status: 'valid')

      expect do
        described_class.new(user: user, organization: organization, rating: 5).call
      end.to raise_error(described_class::AttendanceRequiredError)
    end

    it 'raises AttendanceRequiredError when user only has a cancelled ticket' do
      create(:ticket, user: user, event: past_event, status: 'cancelled')

      expect do
        described_class.new(user: user, organization: organization, rating: 5).call
      end.to raise_error(described_class::AttendanceRequiredError)
    end

    it 'raises AttendanceRequiredError when user only attended an event of another organization' do
      other_event = create(:event, :past)
      create(:ticket, user: user, event: other_event, status: 'valid')

      expect do
        described_class.new(user: user, organization: organization, rating: 5).call
      end.to raise_error(described_class::AttendanceRequiredError)
    end

    it 'raises AlreadyReviewedError when user already reviewed the organization' do
      create(:ticket, user: user, event: past_event, status: 'valid')
      create(:organization_review, user: user, organization: organization)

      expect do
        described_class.new(user: user, organization: organization, rating: 4).call
      end.to raise_error(described_class::AlreadyReviewedError)
    end

    it 'raises RecordInvalid when rating is invalid' do
      create(:ticket, user: user, event: past_event, status: 'valid')

      expect do
        described_class.new(user: user, organization: organization, rating: 6).call
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
