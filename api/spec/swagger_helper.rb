# frozen_string_literal: true

require 'rails_helper'

# OpenAPI document generated from the rswag request specs:
#   bundle exec rake rswag:specs:swaggerize   # writes swagger/v1/swagger.yaml
RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  api_port = ENV.fetch('PORT', '3000')

  timestamp = { type: :string, format: 'date-time', nullable: true }
  user_summary = {
    type: :object,
    nullable: true,
    properties: {
      id: { type: :integer },
      email: { type: :string },
      first_name: { type: :string },
      last_name: { type: :string }
    }
  }

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Come2Kids API',
        version: 'v1',
        description: 'Errors use { code, message, details }; one exception: PUT /api/v1/users/me answers an '                      'invalid profile with 422 { errors: [...] }. Collections return { data, pagination }.'
      },
      # The relative server sends "Try it out" requests to the host Swagger UI was opened from, so it works on
      # localhost, 127.0.0.1 and 0.0.0.0 without CORS. The templated server targets a host explicitly.
      servers: [
        { url: '/', description: 'Same host as this Swagger UI' },
        {
          url: 'http://{host}:{port}',
          description: 'Local API',
          variables: {
            host: { default: 'localhost', enum: %w[localhost 127.0.0.1 0.0.0.0] },
            port: { default: api_port }
          }
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, bearerFormat: 'JWT' }
        },
        schemas: {
          error: {
            type: :object,
            properties: {
              code: { type: :string, example: 'UNAUTHORIZED' },
              message: { type: :string },
              details: {
                type: :array,
                items: {
                  type: :object,
                  properties: { field: { type: :string }, message: { type: :string }, error: { type: :string } }
                }
              }
            },
            required: %w[code]
          },
          pagination: {
            type: :object,
            properties: {
              page: { type: :integer },
              pageSize: { type: :integer },
              totalCount: { type: :integer },
              totalPages: { type: :integer }
            },
            required: %w[page pageSize totalCount totalPages]
          },
          user_profile: {
            type: :object,
            properties: {
              id: { type: :integer },
              email: { type: :string },
              first_name: { type: :string },
              last_name: { type: :string },
              phone: { type: :string, nullable: true },
              birth_date: { type: :string, format: :date, nullable: true },
              city: { type: :string, nullable: true },
              preferred_locale: { type: :string, enum: %w[uk en] }
            },
            required: %w[id email first_name last_name preferred_locale]
          },
          user_summary: user_summary,
          moderation_user: {
            type: :object,
            properties: {
              id: { type: :integer },
              email: { type: :string },
              platform_role: { type: :string, enum: %w[user moderator] },
              blocked: { type: :boolean },
              block_reason: { type: :string, nullable: true },
              blocked_by_id: { type: :integer, nullable: true },
              blocked_at: timestamp
            },
            required: %w[id email blocked]
          },
          moderation_organization: {
            type: :object,
            properties: {
              id: { type: :integer },
              slug: { type: :string },
              name: { type: :string },
              status: { type: :string, enum: Organization::STATUSES },
              rejection_reason: { type: :string, nullable: true },
              block_reason: { type: :string, nullable: true },
              approved_by_id: { type: :integer, nullable: true },
              blocked_by_id: { type: :integer, nullable: true },
              owner: user_summary,
              translations: { type: :array, items: { type: :object } },
              approved_at: timestamp,
              blocked_at: timestamp
            },
            required: %w[id slug status]
          },
          moderation_event: {
            type: :object,
            properties: {
              id: { type: :integer },
              status: { type: :string, enum: Event::STATUSES },
              title: { type: :string, nullable: true },
              rejection_reason: { type: :string, nullable: true },
              reviewed_by_id: { type: :integer, nullable: true },
              translations: { type: :array, items: { type: :object } },
              organization: { type: :object },
              created_by: user_summary,
              start_at: timestamp,
              published_at: timestamp
            },
            required: %w[id status]
          },
          appeal: {
            type: :object,
            properties: {
              id: { type: :integer },
              target_type: { type: :string, enum: Appeal::TARGET_TYPES },
              target_id: { type: :integer },
              status: { type: :string, enum: Appeal::STATUSES },
              message: { type: :string },
              decision_reason: { type: :string, nullable: true },
              reviewed_at: timestamp,
              created_at: timestamp
            },
            required: %w[id target_type target_id status message]
          },
          moderation_log: {
            type: :object,
            properties: {
              id: { type: :integer },
              entity_type: { type: :string },
              entity_id: { type: :integer },
              moderator_id: { type: :integer, nullable: true },
              decision: { type: :string, enum: ModerationLog::DECISIONS },
              reason: { type: :string, nullable: true },
              created_at: timestamp
            },
            required: %w[id entity_type entity_id decision]
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
            properties: { data: { '$ref' => '#/components/schemas/eventMedia' } },
            required: %w[data]
          },
          eventMediaList: {
            type: :object,
            properties: {
              data: { type: :array, items: { '$ref' => '#/components/schemas/eventMedia' } }
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
              price: { type: :integer, description: 'Price in minor units. 0 means free.' },
              total_quantity: { type: :integer },
              sale_start_at: { type: :string, format: 'date-time', nullable: true },
              sale_end_at: { type: :string, format: 'date-time', nullable: true }
            },
            required: %w[name price total_quantity]
          },
          draftEvent: {
            type: :object,
            properties: {
              category_id: { type: :integer, nullable: true },
              start_at: { type: :string, format: 'date-time', nullable: true },
              end_at: { type: :string, format: 'date-time', nullable: true },
              time_zone: { type: :string },
              location_type: { type: :string, enum: %w[offline online], nullable: true },
              address: { type: :string, nullable: true },
              city: { type: :string, nullable: true },
              online_url: { type: :string, nullable: true },
              translations: { type: :array, items: { '$ref' => '#/components/schemas/draftEventTranslation' } },
              ticket_types: { type: :array, items: { '$ref' => '#/components/schemas/draftTicketType' } }
            }
          },
          draftEventRequest: {
            type: :object,
            properties: { event: { '$ref' => '#/components/schemas/draftEvent' } },
            required: %w[event]
          },
          managedEvent: {
            type: :object,
            properties: {
              id: { type: :integer },
              status: { type: :string, example: 'draft' },
              time_zone: { type: :string },
              location_type: { type: :string, nullable: true },
              address: { type: :string, nullable: true },
              city: { type: :string, nullable: true },
              online_url: { type: :string, nullable: true },
              banner_url: { type: :string, nullable: true },
              title: { type: :string, nullable: true },
              start_at: { type: :string, format: 'date-time', nullable: true },
              end_at: { type: :string, format: 'date-time', nullable: true },
              category_id: { type: :integer, nullable: true },
              event_translations: { type: :array, items: { type: :object } },
              ticket_types: { type: :array, items: { type: :object } }
            },
            required: %w[id status]
          },
          managedEventResponse: {
            type: :object,
            properties: { data: { '$ref' => '#/components/schemas/managedEvent' } },
            required: %w[data]
          },
          eventRevision: {
            type: :object,
            properties: {
              id: { type: :integer },
              status: { type: :string, example: "under_review" },
              payload: { type: :object },
              submitted_by_id: { type: :integer },
              reviewed_by_id: { type: :integer, nullable: true },
              reviewed_at: { type: :string, format: "date-time", nullable: true },
              rejection_reason: { type: :string, nullable: true }
            },
            required: %w[id status payload]
          },
          eventRevisionResponse: {
            type: :object,
            properties: { data: { "$ref" => "#/components/schemas/eventRevision" } },
            required: %w[data]
          },
          participantTicket: {
            type: :object,
            properties: {
              id: { type: :integer },
              holder_name: { type: :string },
              ticket_type_name: { type: :string, nullable: true },
              check_in_state: { type: :string }
            },
            required: %w[id holder_name check_in_state]
          },
          participantPage: {
            type: :object,
            properties: {
              data: { type: :array, items: { "$ref" => "#/components/schemas/participantTicket" } },
              pagination: { type: :object }
            },
            required: %w[data pagination]
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
