# frozen_string_literal: true

module Events
  # Replaces the editable fields of a draft or rejected event. Returns Dry::Monads::Result.
  class UpdateDraft
    include Dry::Monads[:result]

    EVENT_ATTRIBUTES = CreateDraft::EVENT_ATTRIBUTES

    def self.call(event:, attributes:)
      new(event:, attributes:).call
    end

    def initialize(event:, attributes:)
      @event = event
      @attributes = attributes.to_h.deep_symbolize_keys
    end

    def call
      assign_attributes
      saved = false
      ActiveRecord::Base.transaction do
        replace_translations if @attributes.key?(:translations)
        replace_ticket_types if @attributes.key?(:ticket_types)
        collect_errors
        raise ActiveRecord::Rollback if @event.errors.any?

        @event.save!
        @event.event_translations.each(&:save!)
        @event.ticket_types.each(&:save!)
        saved = true
      end
      saved ? Success(@event) : Failure(@event)
    rescue ActiveRecord::RecordInvalid => e
      Failure(e.record)
    end

    private

    def assign_attributes
      attrs = @attributes.slice(*EVENT_ATTRIBUTES)
      attrs.delete(:time_zone) if attrs[:time_zone].blank?
      @event.assign_attributes(attrs)
    end

    def replace_translations
      @event.event_translations.destroy_all
      Array(@attributes[:translations]).each do |raw|
        values = raw.to_h.symbolize_keys.slice(:locale, :title, :description)
        @event.event_translations.build(values)
      end
    end

    def replace_ticket_types
      @event.ticket_types.destroy_all
      Array(@attributes[:ticket_types]).each do |raw|
        values = raw.to_h.symbolize_keys
        @event.ticket_types.build(
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

    def collect_errors
      @event.validate
      reject_duplicate_locales
      @event.event_translations.each { |translation| copy_errors(translation, 'translations') }
      @event.ticket_types.each_with_index do |ticket_type, index|
        copy_errors(ticket_type, "ticket_types[#{index}]")
      end
    end

    def reject_duplicate_locales
      locales = @event.event_translations.map(&:locale).compact
      return if locales.uniq.size == locales.size

      @event.errors.add(:translations, 'locale must be unique')
    end

    def copy_errors(record, prefix)
      return if record.valid?

      record.errors.each do |error|
        @event.errors.add("#{prefix}.#{error.attribute}", error.message)
      end
    end
  end
end
