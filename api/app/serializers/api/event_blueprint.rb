# frozen_string_literal: true

module Api
  class EventBlueprint < Blueprinter::Base
    identifier :id

    fields :time_zone, :location_type, :address, :city, :online_url, :banner_url, :status

    field :title do |event|
      event.event_translations.find { |t| t.locale == I18n.locale.to_s }&.title
    end

    field :start_at do |event|
      event.start_at&.utc&.iso8601(3)
    end

    field :end_at do |event|
      event.end_at&.utc&.iso8601(3)
    end

    field :finished do |event|
      event.end_at.present? && event.end_at < Time.current
    end

    view :detail do
      field :description do |event|
        translation = event.event_translations.find { |t| t.locale == I18n.locale.to_s }
        translation&.description
      end
      association :ticket_types, blueprint: Api::TicketTypeBlueprint
    end

    association :category, blueprint: Api::CategoryBlueprint
    association :organization, blueprint: Api::OrganizationBlueprint

    view :managed do
      field :category_id

      association :event_translations, blueprint: Api::EventTranslationBlueprint
      association :ticket_types, blueprint: Api::TicketTypeBlueprint
    end
  end
end
