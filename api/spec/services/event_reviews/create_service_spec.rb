# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventReviews::CreateService do
  let(:user) { create(:user) }
  let(:event) { create(:event, :past) }

  describe '#call' do
    context 'when user has a valid ticket and event has ended' do
      before { create(:ticket, user: user, event: event, status: 'valid') }

      it 'creates and returns an event review' do
        review = described_class.new(user: user, event: event, rating: 5, text: 'Супер!').call

        expect(review).to be_persisted
        expect(review.rating).to eq(5)
        expect(review.text).to eq('Супер!')
        expect(review.user).to eq(user)
        expect(review.event).to eq(event)
      end
    end

    context 'when user has a used ticket and event has ended' do
      before { create(:ticket, user: user, event: event, status: 'used') }

      it 'creates an event review' do
        expect do
          described_class.new(user: user, event: event, rating: 4).call
        end.to change(EventReview, :count).by(1)
      end
    end

    context 'when event has not ended yet' do
      let(:event) { create(:event) }

      before { create(:ticket, user: user, event: event, status: 'valid') }

      it 'raises EventNotEndedError' do
        expect do
          described_class.new(user: user, event: event, rating: 5).call
        end.to raise_error(described_class::EventNotEndedError)
      end
    end

    context 'when user has no ticket for the event' do
      it 'raises TicketRequiredError' do
        expect do
          described_class.new(user: user, event: event, rating: 5).call
        end.to raise_error(described_class::TicketRequiredError)
      end
    end

    context 'when user only has a cancelled ticket' do
      before { create(:ticket, user: user, event: event, status: 'cancelled') }

      it 'raises TicketRequiredError' do
        expect do
          described_class.new(user: user, event: event, rating: 5).call
        end.to raise_error(described_class::TicketRequiredError)
      end
    end

    context 'when user has already reviewed the event' do
      before do
        create(:ticket, user: user, event: event, status: 'valid')
        create(:event_review, user: user, event: event)
      end

      it 'raises AlreadyReviewedError' do
        expect do
          described_class.new(user: user, event: event, rating: 5).call
        end.to raise_error(described_class::AlreadyReviewedError)
      end
    end
  end
end
