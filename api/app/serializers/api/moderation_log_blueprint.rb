# frozen_string_literal: true

module Api
  # A moderation decision (FR-MOD-3): who, when, what and why.
  class ModerationLogBlueprint < Blueprinter::Base
    identifier :id

    fields :entity_type, :entity_id, :moderator_id, :decision, :reason

    field(:created_at) { |log| ModerationFields.time(log.created_at) }
  end
end
