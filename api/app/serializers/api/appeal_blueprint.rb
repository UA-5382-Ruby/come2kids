# frozen_string_literal: true

module Api
  # Appeals (US-6.5). The default view is what the appellant sees; the :moderator view adds the
  # target with its block details, so a moderator other than the one who blocked can pick it (FR-APP-5).
  class AppealBlueprint < Blueprinter::Base
    identifier :id

    fields :target_type, :target_id, :status, :message, :decision_reason

    %i[reviewed_at created_at updated_at].each do |attribute|
      field(attribute) { |appeal| ModerationFields.time(appeal.public_send(attribute)) }
    end

    view :moderator do
      fields :submitted_by_id, :reviewed_by_id

      field(:submitted_by) { |appeal| ModerationFields.user_summary(appeal.submitted_by) }

      field :target do |appeal|
        target = appeal.target
        summary = { blocked: target.blocked?, block_reason: target.block_reason, blocked_by_id: target.blocked_by_id,
                    blocked_at: ModerationFields.time(target.blocked_at) }
        if target.is_a?(Organization)
          summary.merge(id: target.id, slug: target.slug, name: target.name, status: target.status)
        else
          summary.merge(ModerationFields.user_summary(target))
        end
      end
    end
  end
end
