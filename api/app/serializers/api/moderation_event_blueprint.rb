# frozen_string_literal: true

module Api
  # An event as moderators see it in the review queue: every language version (FR-I18N-5),
  # its organization and its creator.
  class ModerationEventBlueprint < Blueprinter::Base
    identifier :id

    fields :status, :category_id, :time_zone, :location_type, :address, :city, :online_url, :banner_url,
           :rejection_reason, :reviewed_by_id

    field(:title) { |event| event.title }

    field :translations do |event|
      event.event_translations.map do |translation|
        { locale: translation.locale, title: translation.title, description: translation.description }
      end
    end

    field :organization do |event|
      organization = event.organization
      { id: organization.id, slug: organization.slug, name: organization.name, status: organization.status }
    end

    field(:created_by) { |event| ModerationFields.user_summary(event.created_by) }

    %i[start_at end_at submitted_at published_at created_at updated_at].each do |attribute|
      field(attribute) { |event| ModerationFields.time(event.public_send(attribute)) }
    end
  end
end
