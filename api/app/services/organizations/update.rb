# frozen_string_literal: true

module Organizations
  class Update
    include Dry::Monads[:result]

    ORGANIZATION_ATTRIBUTES = %i[
      contact_email
      phone
      website
      address
      city
    ].freeze

    def self.call(organization:, user:, **attrs)
      new(organization: organization, user: user, **attrs).call
    end

    def initialize(organization:, user:, **attrs)
      @organization = organization
      @user = user
      @attrs = attrs.compact
    end

    def call
      return Failure(:organization_blocked) if @organization.blocked?

      org_attrs = @attrs.slice(*ORGANIZATION_ATTRIBUTES)
      @organization.assign_attributes(org_attrs) if org_attrs.any?

      translation.name = @attrs[:name] if @attrs.key?(:name)
      translation.description = @attrs[:description] if @attrs.key?(:description)

      if @organization.valid? && translation.valid?
        @organization.save!
        Success(@organization)
      else
        @organization.errors.merge!(translation.errors)
        Failure(@organization.errors)
      end
    rescue ActiveRecord::RecordInvalid => e
      # ✅ Безпечна обробка: якщо record nil — повертаємо базову помилку
      if e.record&.respond_to?(:errors)
        Failure(e.record.errors)
      else
        Failure({ base: e.message })
      end
    end

    private

    def translation
      @translation ||= @organization.organization_translations
                                    .find_or_initialize_by(locale: I18n.locale)
    end
  end
end