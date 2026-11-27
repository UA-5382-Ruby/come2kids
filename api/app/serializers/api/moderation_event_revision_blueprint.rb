# frozen_string_literal: true

module Api
  # A pending edit of a published event as moderators see it (FR-MOD-6): the event it belongs to, who
  # submitted it, the full proposed payload and the changed fields with old and new values side by side.
  # `changes` compares with the live event, so it is null once the revision is decided.
  class ModerationEventRevisionBlueprint < Blueprinter::Base
    identifier :id

    fields :event_id, :status, :rejection_reason, :reviewed_by_id

    field :event do |revision|
      event = revision.event
      organization = event.organization
      {
        id: event.id, title: event.title, status: event.status,
        organization: { id: organization.id, slug: organization.slug, name: organization.name }
      }
    end

    field(:submitted_by) { |revision| ModerationFields.user_summary(revision.submitted_by) }
    field(:proposed) { |revision| revision.payload }
    field(:changes) { |revision| Events::Revisions::Diff.call(revision) if revision.pending? }

    %i[reviewed_at created_at updated_at].each do |attribute|
      field(attribute) { |revision| ModerationFields.time(revision.public_send(attribute)) }
    end
  end
end
