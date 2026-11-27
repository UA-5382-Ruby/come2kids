# frozen_string_literal: true

module Api
  class OrganizationBlueprint < Blueprinter::Base
    identifier :id

    fields :slug, :city, :logo_url, :reviews_count

    field :average_rating do |organization|
      organization.average_rating&.to_f
    end

    field :name do |organization|
      organization.organization_translations.find { |t| t.locale == I18n.locale.to_s }&.name
    end
  end
end
