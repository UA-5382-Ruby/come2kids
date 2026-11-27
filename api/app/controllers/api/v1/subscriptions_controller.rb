# frozen_string_literal: true

module Api
  module V1
    # Following events and organizations (US-12.1, FR-SUB-1, FR-SUB-5).
    class SubscriptionsController < ApplicationController
      before_action :authenticate_user!, except: :unsubscribe

      def my
        authorize Subscription
        subscriptions, pagination = paginate_collection(
          filter_by_target_type(current_user.subscriptions.includes(:target)),
          sortable: { created_at: :created_at },
          default_sort: :created_at
        )

        render_collection subscriptions, blueprint: Api::SubscriptionBlueprint, pagination: pagination
      end

      def create
        authorize Subscription

        result = ::Subscriptions::Create.call(
          user: current_user,
          target_type: params.require(:target_type),
          target_id: params.require(:target_id)
        )
        render_result result, blueprint: Api::SubscriptionBlueprint, status: :created
      end

      def destroy
        subscription = Subscription.find(params[:id])
        authorize subscription

        subscription.destroy!
        head :no_content
      end

      # One-click unsubscribe from an email link, without logging in (FR-SUB-4). Repeating it is harmless.
      def unsubscribe
        authorize Subscription

        subscription_id = ::Subscriptions::UnsubscribeToken.verify(params[:token])
        raise ApiError, :token_invalid if subscription_id.nil?

        Subscription.where(id: subscription_id).destroy_all
        render json: { data: { unsubscribed: true } }, status: :ok
      end

      private

      # ?target_type=event|organization, the same names the API returns.
      def filter_by_target_type(relation)
        value = params[:target_type].presence
        return relation if value.nil?

        model = ::Subscriptions::Create::TARGETS[value.to_s.downcase]
        invalid_query_parameter(:target_type, 'must be event or organization') unless model
        relation.where(target_type: model.name)
      end
    end
  end
end
