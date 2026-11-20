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
              message: { type: :string },
              details: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    field: { type: :string },
                    error: { type: :string },
                    message: { type: :string }
                  }
                }
              }
            },
            required: %w[code]
          },
          eventMedia: {
            type: :object,
            properties: {
              id: { type: :integer },
              kind: { type: :string, enum: %w[banner gallery] },
              position: { type: :integer },
              url: { type: :string },
              content_type: { type: :string },
              byte_size: { type: :integer }
            },
            required: %w[id kind position url content_type byte_size]
          },
          eventMediaResponse: {
            type: :object,
            properties: { data: { "$ref" => "#/components/schemas/eventMedia" } },
            required: %w[data]
          },
          eventMediaList: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/eventMedia" } }
            },
            required: %w[data]
          },
          eventImageOrder: {
            type: :object,
            properties: {
              image_ids: { type: :array, items: { type: :integer } }
            },
            required: %w[image_ids]
          },
          draftEventTranslation: {
            type: :object,
            properties: {
              locale: { type: :string, enum: %w[uk en] },
              title: { type: :string },
              description: { type: :string, nullable: true }
            },
            required: %w[locale title]
          },
          draftTicketType: {
            type: :object,
            properties: {
              name: { type: :string },
              price: { type: :integer, description: "Price in minor units. 0 means free." },
              total_quantity: { type: :integer },
              sale_start_at: { type: :string, format: "date-time", nullable: true },
              sale_end_at: { type: :string, format: "date-time", nullable: true }
            },
            required: %w[name price total_quantity]
          },
          draftEvent: {
            type: :object,
            properties: {
              category_id: { type: :integer, nullable: true },
              start_at: { type: :string, format: "date-time", nullable: true },
              end_at: { type: :string, format: "date-time", nullable: true },
              time_zone: { type: :string },
              location_type: { type: :string, enum: %w[offline online], nullable: true },
              address: { type: :string, nullable: true },
              city: { type: :string, nullable: true },
              online_url: { type: :string, nullable: true },
              translations: { type: :array, items: { "$ref" => "#/components/schemas/draftEventTranslation" } },
              ticket_types: { type: :array, items: { "$ref" => "#/components/schemas/draftTicketType" } }
            }
          },
          draftEventRequest: {
            type: :object,
            properties: { event: { "$ref" => "#/components/schemas/draftEvent" } },
            required: %w[event]
          },
          managedEvent: {
            type: :object,
            properties: {
              id: { type: :integer },
              status: { type: :string, example: "draft" },
              time_zone: { type: :string },
              location_type: { type: :string, nullable: true },
              address: { type: :string, nullable: true },
              city: { type: :string, nullable: true },
              online_url: { type: :string, nullable: true },
              banner_url: { type: :string, nullable: true },
              title: { type: :string, nullable: true },
              start_at: { type: :string, format: "date-time", nullable: true },
              end_at: { type: :string, format: "date-time", nullable: true },
              category_id: { type: :integer, nullable: true },
              event_translations: { type: :array, items: { type: :object } },
              ticket_types: { type: :array, items: { type: :object } }
            },
            required: %w[id status]
          },
          managedEventResponse: {
            type: :object,
            properties: { data: { "$ref" => "#/components/schemas/managedEvent" } },
            required: %w[data]
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
