# frozen_string_literal: true

module Tickets
  class CheckIn
    include Dry::Monads[:result]

    def self.call(event:, token:, user:)
      new(event: event, token: token, user: user).call
    end

    def initialize(event:, token:, user:)
      @event = event
      @token = token.to_s
      @user = user
    end

    def call
      problem = precheck
      return Failure(problem) if problem

      claim
    end

    private

    def precheck
      return error(Api::ErrorCodes::BAD_REQUEST, 'QR token is required.') if @token.blank?

      @ticket = Ticket.includes(:user, :ticket_type).find_by(qr_token: @token, event_id: @event.id)
      return error(Api::ErrorCodes::NOT_FOUND, 'Ticket not found for this event.') if @ticket.nil?
      return error(Api::ErrorCodes::INVALID_STATUS_TRANSITION, 'The event is cancelled.') if event_cancelled?
      return error(Api::ErrorCodes::INVALID_STATUS_TRANSITION, 'The ticket is cancelled.') if @ticket.status_cancelled?

      nil
    end

    def claim
      changed = Ticket.where(id: @ticket.id, status: 'valid').update_all(
        status: 'used', used_at: Time.current, checked_in_by_id: @user.id, updated_at: Time.current
      )
      return Failure(error(Api::ErrorCodes::CONFLICT, 'The ticket has already been used.')) if changed.zero?

      Success(@ticket.reload)
    end

    def event_cancelled?
      @event.status.to_s.start_with?('cancelled')
    end

    def error(code, message)
      Api::ApplicationError.new(code: code, message: message)
    end
  end
end
