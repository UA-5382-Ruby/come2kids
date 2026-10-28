module ResponseRenderer
    private

    def render_resource(record, serializer:, status: :ok)
       render json: { data: serializer.new(record).to_h }, status: status
    end

    def render_collection(records, serializer:, meta: {})
       render json: { data: serializer.new(records).to_h, meta: meta }
    end
end