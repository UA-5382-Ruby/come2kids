module Paginatable
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100

    private

    def paginate(scope)
       page = positive_int(params[:page], default: 1, name: "page")
       page_size = positive_int(params[:pageSize], default: DEFAULT_PAGE_SIZE, name: "pageSize")
       page_size = [page_size, MAX_PAGE_SIZE].min

       total = scope.except(:order).count
       records = scope.offset((page - 1) * page_size).limit(page_size)

       [records, { page: page, pageSize: page_size, total: total,
                   totalPages: (total.to_f / page_size).ceil }]
    end

    def positive_int(value, default:, name:)
       return default if value.blank?
       int = Integer(value, exception: false)
       raise Api::Error.new(:invalid_parameter, details: { param: name }) unless int&.positive?
       int
    end
end