# frozen_string_literal: true

module Events
  class CatalogQuery
    def self.call(params, locale: I18n.locale)
      new(params, locale: locale).call
    end

    def initialize(params, locale:)
      @params = params
      @locale = locale.to_s
    end

    def call
      scope = base_scope
      scope = by_date_range(scope)
      scope = by_location_type(scope)
      by_search(scope)
    end

    private

    # Event.publicly_visible hides events of blocked, pending and rejected organizations (FR-MOD-5),
    # so the catalog and moderation share one definition of what the public may see.
    def base_scope
      Event.publicly_visible
           .includes(:category, :event_translations, organization: :organization_translations)
    end

    def by_date_range(scope)
      from = parse_time(:date_from)
      to = parse_time(:date_to)
      scope = scope.where('events.start_at >= ?', from) if from
      scope = scope.where('events.start_at <= ?', to) if to
      scope
    end

    def by_location_type(scope)
      value = @params[:location_type].presence
      return scope if value.blank?
      return scope.where(location_type: value) if Event::LOCATION_TYPES.include?(value)

      raise invalid_parameter(:location_type, 'must be offline or online')
    end

    def by_search(scope)
      query = @params[:q].to_s.strip
      return scope if query.blank?

      matching_ids = EventTranslation.where(locale: @locale)
                                     .where('event_translations.title ILIKE ?', "%#{Event.sanitize_sql_like(query)}%")
                                     .select(:event_id)
      scope.where(id: matching_ids)
    end

    def parse_time(key)
      raw = @params[key].presence
      return nil if raw.blank?

      parsed = Time.zone.parse(raw.to_s)
      raise invalid_parameter(key, 'must be a valid ISO 8601 datetime') if parsed.nil?

      parsed
      rescue ArgumentError, TypeError
        raise invalid_parameter(key, 'must be a valid ISO 8601 datetime')
    end

    def invalid_parameter(field, message)
      Api::ApplicationError.new(
        code: Api::ErrorCodes::BAD_REQUEST,
        message: 'Invalid query parameters.',
        details: [ { field: field.to_s, message: message } ]
      )
    end
  end
end
