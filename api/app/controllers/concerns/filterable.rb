module Filterable
   RANGE_SUFFIX = /\A(?<field>.+)_(?<bound>from|to)\z/

   private

   # allowed: fields supporting exact match (or IN via filter[status][]=a&filter[status][]=b)
   # ranges:  { field => :time | :integer }, exposed as <field>_from / <field>_to
   def apply_filters(scope, allowed: [], ranges: {})
      raw = params[:filter]
      return scope if raw.blank?

      unless raw.respond_to?(:to_unsafe_h)
         raise invalid_filter("filter must be an object, e.g. filter[status]=active")
      end

      filters    = raw.to_unsafe_h
      exact_keys = allowed.map(&:to_s)
      range_keys = ranges.keys.flat_map { |f| ["#{f}_from", "#{f}_to"] }
      nknown    = filters.keys - exact_keys - range_keys

      if unknown.any?
         raise Api::Error.new(:invalid_parameter, details: {
         param: "filter", unknown: unknown, allowed: exact_keys + range_keys
         })
      end

      bounds = Hash.new { |h, k| h[k] = {} } # field => { from: x, to: y }

      filters.each do |key, value|
         if (m = RANGE_SUFFIX.match(key)) && ranges.key?(m[:field].to_sym)
         field = m[:field].to_sym
         bounds[field][m[:bound].to_sym] = parse_range_value(value, ranges[field], key)
         else
         scope = scope.where(key => scalar_or_list(value, key))
         end
      end

      bounds.each do |field, b|
         if b[:from] && b[:to] && b[:from] > b[:to]
         raise invalid_filter("#{field}_from must be <= #{field}_to", field: field.to_s)
         end
         scope = scope.where(field => (b[:from]..b[:to])) # endless/beginless ranges are fine
      end

      scope
   end

   def parse_range_value(value, type, name)
      case type
      when :time    then parse_time(value, name: name)
      when :integer then parse_integer(value, name: name)
      else raise ArgumentError, "Unsupported range type: #{type.inspect}"
      end
   end

   # Requires a full ISO 8601 timestamp with Z or offset, e.g. 2025-01-01T00:00:00Z
   def parse_time(value, name:)
      str = value.to_s
      unless str.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})\z/)
         raise Api::Error.new(:invalid_parameter, details: { param: name, expected: "ISO 8601 with Z or offset" })
      end
      Time.iso8601(str).utc
   rescue ArgumentError
      raise Api::Error.new(:invalid_parameter, details: { param: name, expected: "ISO 8601 with Z or offset" })
   end

   # For amounts in minor units
   def parse_integer(value, name:)
      Integer(value.to_s, 10)
   rescue ArgumentError
      raise Api::Error.new(:invalid_parameter, details: { param: name, expected: "integer" })
   end

   # Rejects nested objects like filter[status][x]=1, which ActiveRecord would treat as a table reference
   def scalar_or_list(value, name)
      ok = value.is_a?(String) || (value.is_a?(Array) && value.all?(String))
      raise Api::Error.new(:invalid_parameter, details: { param: "filter[#{name}]" }) unless ok
      value
   end

   def invalid_filter(message, extra = {})
      Api::Error.new(:invalid_parameter, message: message, details: { param: "filter" }.merge(extra))
   end
end