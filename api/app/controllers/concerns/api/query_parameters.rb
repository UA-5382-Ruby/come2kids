# frozen_string_literal: true

module Api
  module QueryParameters
    extend ActiveSupport::Concern

    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100
    SORT_DIRECTIONS = %w[asc desc].freeze

    private

    def paginate_collection(relation, sortable:, filterable: {}, default_sort: nil)
      default_sort ||= sortable.keys.first
      page = query_integer(:page, default: DEFAULT_PAGE, minimum: 1)
      page_size = query_integer(:pageSize, default: DEFAULT_PAGE_SIZE, minimum: 1, maximum: MAX_PAGE_SIZE)
      sort_column = query_column(:sort, sortable, default: default_sort)
      direction = query_direction

      filtered_relation = apply_filters(relation, filterable)
      total_count = filtered_relation.count
      records = filtered_relation
        .order(sort_column => direction)
        .offset((page - 1) * page_size)
        .limit(page_size)

      [
        records,
        {
          page: page,
          pageSize: page_size,
          totalCount: total_count,
          totalPages: (total_count.to_f / page_size).ceil
        }
      ]
    end

    def apply_filters(relation, filterable)
      filterable.reduce(relation) do |filtered_relation, (parameter, column)|
        value = params[parameter.to_s]
        next filtered_relation if value.blank?

        filtered_relation.where(column => value)
      end
    end

    def query_column(parameter, allowed_columns, default:)
      value = params[parameter.to_s].presence || default
      column = allowed_columns.stringify_keys[value.to_s]
      return column if column

      invalid_query_parameter(parameter, 'is not sortable')
    end

    def query_direction
      direction = params['direction'].presence || 'asc'
      return direction if SORT_DIRECTIONS.include?(direction)

      invalid_query_parameter(:direction, 'must be asc or desc')
    end

    def query_integer(parameter, default:, minimum:, maximum: nil)
      value = params[parameter.to_s].presence || default
      integer = value.is_a?(String) ? Integer(value, 10) : Integer(value)
      return integer if integer >= minimum && (maximum.nil? || integer <= maximum)

      invalid_query_parameter(parameter, 'is outside the allowed range')
    rescue ArgumentError, TypeError
      invalid_query_parameter(parameter, 'must be an integer')
    end

    def invalid_query_parameter(parameter, message)
      raise Api::ApplicationError.new(
        code: Api::ErrorCodes::BAD_REQUEST,
        message: 'Invalid query parameters.',
        details: [ { field: parameter.to_s, message: message } ]
      )
    end
  end
end
