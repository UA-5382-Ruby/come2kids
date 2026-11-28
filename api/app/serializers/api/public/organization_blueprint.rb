# frozen_string_literal: true

module Api
  module Public
    class OrganizationBlueprint < Blueprinter::Base
      identifier :id

      field :slug
      field :contact_email
      field :phone
      field :website
      field :address
      field :city
      field :reviews_count
      field :published_events_count
      field :locale do |_organization, _options|
        I18n.locale.to_s
      end

      field :average_rating do |organization, _options|
        organization.average_rating&.to_f
      end

      field :name do |organization, _options|
        organization.name(I18n.locale)
      end

      field :description do |organization, _options|
        translation = organization.organization_translations.find_by(locale: I18n.locale.to_s) ||
                      organization.organization_translations.find_by(locale: 'uk')
        translation&.description
      end

      field :logo_url do |organization, _options|
        if organization.respond_to?(:logo) && organization.logo.attached?
          Rails.application.routes.url_helpers.rails_blob_url(
            organization.logo,
            only_path: true
          )
        else
          organization.logo_url
        end
      end
    end
  end
end
