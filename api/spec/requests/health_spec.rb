# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Health", type: :request do
  path "/up" do
    get "Checks application health" do
      tags "Health"
      produces "text/plain"

      response "200", "application is healthy" do
        schema type: :string

        run_test!
      end
    end
  end
end
