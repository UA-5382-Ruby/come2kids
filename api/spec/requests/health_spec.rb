require "swagger_helper"

RSpec.describe "Health", type: :request do
  path "/up" do
    get "Returns API health status" do
      tags "Health"
      produces "application/json"

      response_schema = {
        type: :object,
        required: %w[status timestamp],
        properties: {
          status: { type: :string, enum: [ "up" ], example: "up" },
          timestamp: { type: :string, format: "date-time" }
        }
      }

      response "200", "API is available" do
        schema response_schema
        run_test!
      end
    end
  end
end
