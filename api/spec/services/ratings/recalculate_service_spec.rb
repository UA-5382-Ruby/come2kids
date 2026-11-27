# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ratings::RecalculateService do
  describe '#call' do
    context 'when recalculating for an Event' do
      let(:event) { create(:event) }
      let(:user_one) { create(:user) }
      let(:user_two) { create(:user) }
      let(:user_three) { create(:user) }

      it 'updates average_rating and reviews_count on create and update' do
        review_one = create(:event_review, event: event, user: user_one, rating: 4)
        create(:event_review, event: event, user: user_two, rating: 5)
        create(:event_review, event: event, user: user_three, rating: 5)

        expect(event.reload.reviews_count).to eq(3)
        expect(event.average_rating).to eq(BigDecimal('4.67'))

        review_one.update!(rating: 1)
        expect(event.reload.reviews_count).to eq(3)
        expect(event.average_rating).to eq(BigDecimal('3.67'))
      end

      it 'resets average_rating and reviews_count when all reviews are destroyed' do
        create(:event_review, event: event, user: user_one, rating: 4)
        event.event_reviews.destroy_all

        expect(event.reload.reviews_count).to eq(0)
        expect(event.average_rating).to be_nil
      end
    end

    context 'when recalculating for an Organization' do
      let(:organization) { create(:organization) }
      let(:user_one) { create(:user) }
      let(:user_two) { create(:user) }

      it 'updates average_rating and reviews_count on create and destroy' do
        review = create(:organization_review, organization: organization, user: user_one, rating: 5)
        create(:organization_review, organization: organization, user: user_two, rating: 4)

        expect(organization.reload.reviews_count).to eq(2)
        expect(organization.average_rating).to eq(BigDecimal('4.5'))

        review.destroy!
        expect(organization.reload.reviews_count).to eq(1)
        expect(organization.average_rating).to eq(BigDecimal('4.0'))
      end
    end

    context 'when record type is unsupported' do
      it 'raises ArgumentError' do
        expect { described_class.new(create(:user)).call }.to raise_error(ArgumentError)
      end
    end
  end
end
