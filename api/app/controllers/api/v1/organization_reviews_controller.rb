# frozen_string_literal: true

module Api
  module V1
    class OrganizationReviewsController < ApplicationController
      before_action :authenticate_user!, except: [ :index ]

      def index
        authorize OrganizationReview
        organization = Organization.find(params[:organization_id])
        reviews, pagination = paginate_collection(
          organization.organization_reviews.includes(:user),
          sortable: { created_at: :created_at, rating: :rating },
          default_sort: :created_at
        )

        render_collection reviews, blueprint: Api::OrganizationReviewBlueprint, pagination: pagination
      end

      def create
        authorize OrganizationReview
        organization = Organization.find(params[:organization_id])

        review = OrganizationReviews::CreateService.new(
          user: current_user,
          organization: organization,
          rating: review_params[:rating],
          text: review_params[:text]
        ).call

        render_resource review, blueprint: Api::OrganizationReviewBlueprint, status: :created
      rescue OrganizationReviews::CreateService::AlreadyReviewedError
        render_error(
          code: 'REVIEW_ALREADY_EXISTS',
          message: I18n.t('api_errors.review_already_exists'),
          status: :conflict
        )
      rescue OrganizationReviews::CreateService::AttendanceRequiredError
        render_error(
          code: 'ATTENDANCE_REQUIRED',
          message: I18n.t('api_errors.attendance_required'),
          status: :forbidden
        )
      end

      def update
        review = OrganizationReview.find(params[:id])
        authorize review

        review.update!(review_params)
        render_resource review, blueprint: Api::OrganizationReviewBlueprint
      end

      def destroy
        review = OrganizationReview.find(params[:id])
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
