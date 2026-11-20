# frozen_string_literal: true

module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_user!

      def create
        authorize Order
        if request.headers['Idempotency-Key'].blank?
          return render_error(code: 'PARAMETER_MISSING', message: 'Idempotency-Key is required', status: :bad_request)
        end

        event = Event.find(params[:event_id])

        service = OrderCreationService.new(
          user: current_user,
          event: event,
          ticket_type_id: params[:ticket_type_id],
          quantity: params[:quantity],
          idempotency_key: request.headers['Idempotency-Key']
        )

        order = service.call
        render_resource order, blueprint: Api::OrderBlueprint, status: :created
      rescue OrderCreationService::IdempotencyConflictError => e
        render_error(code: 'IDEMPOTENCY_CONFLICT', message: e.message, status: :conflict)
      rescue OrderCreationService::TicketsSoldOutError => e
        render_error(code: 'EVENT_SOLD_OUT', message: e.message, status: :unprocessable_entity)
      rescue OrderCreationService::EventNotPublishedError, OrderCreationService::InvalidQuantityError => e
        render_error(code: 'UNPROCESSABLE_ENTITY', message: e.message, status: :unprocessable_entity)
      end
    end
  end
end
