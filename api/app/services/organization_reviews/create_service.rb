# frozen_string_literal: true

module OrganizationReviews
  class CreateService
    class AlreadyReviewedError < StandardError; end
    class AttendanceRequiredError < StandardError; end

    def initialize(user:, organization:, rating:, text: nil)
      @user = user
      @organization = organization
      @rating = rating
      @text = text
    end

    def call
      validate_not_already_reviewed!
      validate_attendance!

      OrganizationReview.create!(
        user: @user,
        organization: @organization,
        rating: @rating,
        text: @text
      )
    rescue ActiveRecord::RecordNotUnique
      raise AlreadyReviewedError, 'You have already reviewed this organization'
    end

    private

    def validate_not_already_reviewed!
      return unless OrganizationReview.exists?(user: @user, organization: @organization)

      raise AlreadyReviewedError, 'You have already reviewed this organization'
    end

    def validate_attendance!
      return if attended_organization_event?

      raise AttendanceRequiredError, 'You must attend at least one event of this organization to leave a review'
    end

    def attended_organization_event?
      Ticket.joins(:event)
            .where(user: @user, status: %w[valid used], events: { organization_id: @organization.id })
            .where('events.end_at < ?', Time.current)
            .exists?
    end
  end
end
