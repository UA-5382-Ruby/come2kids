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
      org_attrs = @attrs.slice(*ORGANIZATION_ATTRIBUTES)
      @organization.assign_attributes(org_attrs) if org_attrs.any?

      translation.name = @attrs[:name] if @attrs.key?(:name)
      translation.description = @attrs[:description] if @attrs.key?(:description)

      if @organization.valid? && translation.valid?
        changed = @organization.changed? || translation.changed?
        Organization.transaction do
          @organization.save!
          translation.save!
        end
        notify_subscribers if changed
        Success(@organization)
      else
        @organization.errors.merge!(translation.errors)
        Failure(@organization.errors)
      end
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record.errors)
    end

    private

    # FR-SUB-2: organization info is public as soon as it is saved, so subscribers of an approved
    # organization are told right away. The version keeps two separate edits from being deduplicated.
    def notify_subscribers
      return unless @organization.accepts_event_changes?

      Subscriptions::NotifyJob.perform_later('organization_updated', @organization.id,
                                             'version' => Time.current.to_f.to_s)
    end

    def translation
      @translation ||= @organization.organization_translations
                                    .find_or_initialize_by(locale: I18n.locale)
    end
  end
end
