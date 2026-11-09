# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: { title: "Come2Kids API", version: "v1" },
      servers: [ { url: "http://localhost:3000" } ],
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, bearerFormat: "JWT" }
        },
        schemas: {
          error: {
            type: :object,
            properties: {
              code: { type: :string, example: "UNAUTHORIZED" },
              details: {
                type: :array,
                items: { type: :object, properties: { message: { type: :string } } }
              }
            },
            required: %w[code]
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
