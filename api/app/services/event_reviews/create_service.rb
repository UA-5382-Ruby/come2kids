# frozen_string_literal: true

module EventReviews
  class CreateService
    class EventNotEndedError < StandardError; end
    class TicketRequiredError < StandardError; end
    class AlreadyReviewedError < StandardError; end

    ELIGIBLE_TICKET_STATUSES = %w[valid used].freeze

    def initialize(user:, event:, rating:, text: nil)
      @user = user
      @event = event
      @rating = rating
      @text = text
    end

    def call
      ensure_event_ended!
      ensure_user_has_ticket!
      ensure_not_already_reviewed!

      EventReview.create!(
        user: @user,
        event: @event,
        rating: @rating,
        text: @text
      )
    end

    private

    def ensure_event_ended!
      return if @event.end_at.present? && @event.end_at < Time.current

      raise EventNotEndedError, 'You can only review an event after it has ended'
    end

    def ensure_user_has_ticket!
      has_ticket = Ticket.exists?(
        user: @user,
        event: @event,
        status: ELIGIBLE_TICKET_STATUSES
      )
      return if has_ticket

      raise TicketRequiredError, 'You must hold a ticket for this event to leave a review'
    end

    def ensure_not_already_reviewed!
      return unless EventReview.exists?(user: @user, event: @event)

      raise AlreadyReviewedError, 'You have already reviewed this event'
    end
  end
end
