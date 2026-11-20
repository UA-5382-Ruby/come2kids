# frozen_string_literal: true

module Events
  # Creates an organization event in draft. Returns Dry::Monads::Result.
  class CreateDraft
    include Dry::Monads[:result]

    EVENT_ATTRIBUTES = %i[
      category_id start_at end_at time_zone location_type address city online_url
    ].freeze

    def self.call(organization:, author:, attributes:)
      new(organization:, author:, attributes:).call
    end

    def initialize(organization:, author:, attributes:)
      @organization = organization
      @author = author
      @attributes = attributes.to_h.deep_symbolize_keys
    end

    def call
      event = build_event
      collect_errors(event)
      return Failure(event) if event.errors.any?

      ActiveRecord::Base.transaction do
        event.save!
        event.event_translations.each(&:save!)
        event.ticket_types.each(&:save!)
        Transition.record!(event:, from: nil, to: 'draft', actor: @author)
      end
      Success(event)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    private

    def build_event
      attrs = @attributes.slice(*EVENT_ATTRIBUTES)
      attrs.delete(:time_zone) if attrs[:time_zone].blank?

      event = @organization.events.build(attrs)
      event.created_by = @author
      event.status = 'draft'
      build_translations(event)
      build_ticket_types(event)
      event
    end

    def build_translations(event)
      Array(@attributes[:translations]).each do |raw|
        event.event_translations.build(raw.to_h.symbolize_keys.slice(:locale, :title, :description))
      end
    end

    def build_ticket_types(event)
      Array(@attributes[:ticket_types]).each do |raw|
        values = raw.to_h.symbolize_keys
        event.ticket_types.build(
          name: values[:name],
          price: values[:price],
          total_quantity: values[:total_quantity],
          sale_start_at: values[:sale_start_at],
          sale_end_at: values[:sale_end_at],
          currency: TicketType::CURRENCY,
          sold_quantity: 0
        )
      end
    end

    def collect_errors(event)
      event.validate
      reject_duplicate_locales(event)
      event.event_translations.each { |translation| copy_errors(event, translation, 'translations') }
      event.ticket_types.each_with_index do |ticket_type, index|
        copy_errors(event, ticket_type, "ticket_types[#{index}]")
      end
    end

    def reject_duplicate_locales(event)
      locales = event.event_translations.map(&:locale).compact
      return if locales.uniq.size == locales.size

      event.errors.add(:translations, 'locale must be unique')
    end

    def copy_errors(event, record, prefix)
      return if record.valid?

      record.errors.each do |error|
        event.errors.add("#{prefix}.#{error.attribute}", error.message)
      end
    end
  end
end
