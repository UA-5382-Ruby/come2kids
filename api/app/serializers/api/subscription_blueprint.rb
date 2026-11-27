# frozen_string_literal: true

module Api
  class SubscriptionBlueprint < Blueprinter::Base
    identifier :id

    field :target_type do |subscription|
      subscription.target_type.underscore
    end

    fields :target_id

    field :target_name do |subscription|
      subscription.target_name
    end

    field :created_at do |subscription|
      subscription.created_at.utc.iso8601
    end
  end
end
