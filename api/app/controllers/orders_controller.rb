class OrdersController < ApplicationController
    def index
        scope = apply_filters(
        Order.all,
        allowed: %i[status customer_id],
        ranges:  { created_at: :time, amount_minor: :integer }
        )
        scope = apply_sort(scope, allowed: %w[created_at amount_minor])
        records, meta = paginate(scope)
        render_collection(records, serializer: OrderSerializer, meta: meta)
    end
end