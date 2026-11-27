# frozen_string_literal: true

module Api
  module V1
    class EventReviewsController < ApplicationController
      before_action :authenticate_user!, except: [ :index ]

      def index
        authorize EventReview
        event = Event.find(params[:event_id])
        reviews, pagination = paginate_collection(
          event.event_reviews.includes(:user),
          sortable: { created_at: :created_at, rating: :rating },
          default_sort: :created_at
        )

        render_collection reviews, blueprint: Api::EventReviewBlueprint, pagination: pagination
      end

      def create
        authorize EventReview
        event = Event.find(params[:event_id])

        review = EventReviews::CreateService.new(
          user: current_user,
          event: event,
          rating: review_params[:rating],
          text: review_params[:text]
        ).call

        render_resource review, blueprint: Api::EventReviewBlueprint, status: :created
      rescue EventReviews::CreateService::AlreadyReviewedError => e
        render_error(code: 'REVIEW_ALREADY_EXISTS', message: e.message, status: :conflict)
      rescue EventReviews::CreateService::TicketRequiredError => e
        render_error(code: 'TICKET_REQUIRED', message: e.message, status: :forbidden)
      rescue EventReviews::CreateService::EventNotEndedError => e
        render_error(code: 'EVENT_NOT_ENDED', message: e.message, status: :unprocessable_entity)
      end

      def update
        review = EventReview.find(params[:id])
        authorize review

        review.update!(review_params)
        render_resource review, blueprint: Api::EventReviewBlueprint
      end

      def destroy
        review = EventReview.find(params[:id])
        authorize review

        review.destroy!
        head :no_content
      end

      private

      def review_params
        params.permit(:rating, :text)
      end
    end
  end
end
