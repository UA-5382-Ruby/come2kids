# frozen_string_literal: true

module Ratings
  class RecalculateService
    def initialize(record)
      @record = record
    end

    def call
      return if @record.nil? || @record.destroyed?

      count, avg = reviews_scope.pick(Arel.sql('COUNT(*), AVG(rating)'))
      average = count.to_i.positive? ? avg.to_d.round(2) : nil

      @record.update_columns(
        average_rating: average,
        reviews_count: count.to_i
      )
    end

    private

    def reviews_scope
      case @record
      when Event
        @record.event_reviews
      when Organization
        @record.organization_reviews
      else
        raise ArgumentError, "Unsupported record type: #{@record.class}"
      end
    end
  end
end
