require "swagger_helper"

RSpec.describe "Health", type: :request do
  path "/up" do
    get "Returns API health status" do
      tags "Health"
      produces "application/json"

      response "200", "API is available" do
        run_test!
      end
    end
  end
end
