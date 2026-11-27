# frozen_string_literal: true

module Subscriptions
  # Subscribes a user to an event or an organization (US-12.1, FR-SUB-1). Returns Dry::Monads::Result:
  # Success(subscription) or Failure(Api::ApplicationError), which the controller raises.
  # Only publicly visible targets can be followed: no unpublished, cancelled or deleted events and no
  # blocked, pending or rejected organizations.
  class Create
    include Dry::Monads[:result]

    TARGETS = { 'event' => Event, 'organization' => Organization }.freeze

    def self.call(user:, target_type:, target_id:)
      new(user:, target_type:, target_id:).call
    end

    def initialize(user:, target_type:, target_id:)
      @user = user
      @target_type = target_type.to_s.downcase
      @target_id = target_id
    end

    def call
      model = TARGETS[@target_type]
      return Failure(invalid_target_type) unless model

      target = model.find(@target_id)
      return Failure(unavailable(target)) unless model.publicly_visible.exists?(id: target.id)

      Success(Subscription.create!(user: @user, target: target))
    rescue ActiveRecord::RecordNotUnique
      Failure(already_subscribed)
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:target_id, :taken)

      Failure(already_subscribed)
    end

    private

    def invalid_target_type
      Api::ApplicationError.new(
        code: Api::ErrorCodes::VALIDATION_FAILED, message: I18n.t('subscriptions.errors.invalid_request'),
        details: [ { field: 'target_type', message: I18n.t('subscriptions.errors.invalid_target_type') } ]
      )
    end

    def unavailable(target)
      key = target.is_a?(Event) ? 'event_unavailable' : 'organization_unavailable'
      Api::ApplicationError.new(code: Api::ErrorCodes::SUBSCRIPTION_TARGET_UNAVAILABLE,
                                message: I18n.t("subscriptions.errors.#{key}"))
    end

    def already_subscribed
      Api::ApplicationError.new(code: Api::ErrorCodes::SUBSCRIPTION_ALREADY_EXISTS,
                                message: I18n.t('subscriptions.errors.already_subscribed'))
    end
  end
end
