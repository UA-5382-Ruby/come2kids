# frozen_string_literal: true

module Api
  class EventRevisionBlueprint < Blueprinter::Base
    identifier :id

    fields :status, :payload, :rejection_reason

    field :submitted_by_id
    field :reviewed_by_id

    field :reviewed_at do |revision|
      revision.reviewed_at&.utc&.iso8601(3)
    end
  end
end
