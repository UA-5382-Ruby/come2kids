# frozen_string_literal: true

module Api
  # An organization as moderators see it: every language version (FR-I18N-5), owner and block details.
  class ModerationOrganizationBlueprint < Blueprinter::Base
    identifier :id

    fields :slug, :status, :contact_email, :phone, :website, :address, :city, :logo_url,
           :rejection_reason, :block_reason, :approved_by_id, :blocked_by_id

    field(:name) { |organization| organization.name }

    field :translations do |organization|
      organization.organization_translations.map do |translation|
        { locale: translation.locale, name: translation.name, description: translation.description }
      end
    end

    field(:owner) { |organization| ModerationFields.user_summary(organization.owner) }

    %i[approved_at blocked_at created_at updated_at].each do |attribute|
      field(attribute) { |organization| ModerationFields.time(organization.public_send(attribute)) }
    end
  end
end
