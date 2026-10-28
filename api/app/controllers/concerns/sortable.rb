module Sortable
    private

    def apply_sort(scope, allowed:, default: "-created_at")
        fields = (params[:sort].presence || default).split(",")
        scope = fields.reduce(scope) do |s, f|
            dir = f.start_with?("-") ? :desc : :asc
            col = f.delete_prefix("-")
            unless allowed.map(&:to_s).include?(col)
                raise Api::Error.new(:invalid_parameter, details: { param: "sort", allowed: allowed })
            end
            s.order(col => dir)
        end
        scope.order(:id)
    end
end