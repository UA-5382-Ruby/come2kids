# frozen_string_literal: true

module Api
  class EventReviewBlueprint < Blueprinter::Base
    identifier :id

    fields :event_id, :user_id, :rating, :text

    field :author do |review|
      {
        id: review.user.id,
        first_name: review.user.first_name,
        last_name: review.user.last_name
      }
    end

    field :created_at do |review|
      review.created_at.utc.iso8601
    end

    field :updated_at do |review|
      review.updated_at.utc.iso8601
    end
  end
end
