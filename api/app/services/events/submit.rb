# frozen_string_literal: true

module Events
  # Checks that a draft is ready for moderation, then moves it to under_review.
  # Returns Dry::Monads::Result. An incomplete event is left unchanged.
  class Submit
    include Dry::Monads[:result]

    def self.call(event:, actor:)
      new(event:, actor:).call
    end

    def initialize(event:, actor:)
      @event = event
      @actor = actor
    end

    def call
      collect_gaps
      return Failure(@event) if @event.errors.any?

      Transition.call(event: @event, to: 'under_review', actor: @actor)
    end

    private

    def collect_gaps
      @event.validate
      @event.errors.add(:start_at, :blank) if @event.start_at.blank?
      @event.errors.add(:end_at, :blank) if @event.end_at.blank?
      @event.errors.add(:time_zone, :blank) if @event.time_zone.blank?
      @event.errors.add(:category, :blank) if @event.category_id.blank?
      @event.errors.add(:ticket_types, 'must include at least one') if @event.ticket_types.none?
      require_uk_title
      require_location
    end

    def require_uk_title
      ready = @event.event_translations.any? { |translation| translation.locale == 'uk' && translation.title.present? }
      return if ready

      @event.errors.add(:translations, 'uk title is required')
    end

    def require_location
      case @event.location_type
      when 'offline'
        @event.errors.add(:address, :blank) if @event.address.blank?
      when 'online'
        @event.errors.add(:online_url, :blank) if @event.online_url.blank?
      else
        @event.errors.add(:location_type, 'must be offline with an address or online with a link')
      end
    end
  end
end
