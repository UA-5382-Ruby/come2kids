# API Summary

This document provides an overview of the backend API architecture and current development status.

---

## Overview

The backend is built as a Rails API-only application, located in the `api/` directory. It is designed to serve JSON responses to frontend clients or external services.

---

## Current Status

The foundational API skeleton has been successfully generated. Core directories for models, controllers, policies, and tests are in place. Specific business logic endpoints will be implemented in subsequent tasks.

---

## Error Responses

API errors use the same JSON shape for every endpoint (one exception: `PUT /api/v1/users/me` answers an invalid profile
with `422 { "errors": ["First name ..."] }`):

```json
{
  "code": "VALIDATION_FAILED",
  "message": "The request is invalid.",
  "details": [
    {
      "field": "email",
      "message": "is invalid"
    }
  ]
}
```

`code` is stable for clients, `message` is safe to display, and `details` is always an array. Unexpected server errors are logged by the API and return `INTERNAL_SERVER_ERROR` without internal exception details.

The initial error-code catalog is:

| Code | HTTP status |
| --- | ---: |
| `BAD_REQUEST` | 400 |
| `UNAUTHORIZED` | 401 |
| `FORBIDDEN` | 403 |
| `NOT_FOUND` | 404 |
| `CONFLICT` | 409 |
| `VALIDATION_FAILED` | 422 |
| `TOO_MANY_REQUESTS` | 429 |
| `INTERNAL_SERVER_ERROR` | 500 |
| `INVALID_CREDENTIALS` | 401 |
| `TOKEN_EXPIRED` | 401 |
| `EMAIL_NOT_CONFIRMED` | 403 |
| `USER_BLOCKED` | 403 |
| `INVALID_STATUS_TRANSITION` | 409 |
| `CANNOT_BLOCK_MODERATOR` | 403 |
| `NOT_BLOCKED` | 409 |
| `APPEAL_ALREADY_OPEN` | 409 |
| `APPEAL_COOLDOWN` | 429 |
| `APPEAL_TOKEN_SCOPE` | 403 |
| `SUBSCRIPTION_ALREADY_EXISTS` | 409 |
| `SUBSCRIPTION_TARGET_UNAVAILABLE` | 422 |

---

## Collection Queries

Collection endpoints accept these query parameters:

| Parameter | Default | Description |
| --- | ---: | --- |
| `page` | `1` | One-based page number |
| `pageSize` | `20` | Number of records per page, up to `100` |
| `sort` | Resource-specific | A documented sortable field |
| `direction` | `asc` | `asc` or `desc` |

Filtering parameters are resource-specific and are documented with each endpoint. Unknown sort fields and invalid query values return `BAD_REQUEST`; query values are never interpolated into SQL.

Paginated responses include the count of records after filtering:

```json
{
  "data": [],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 0,
    "totalPages": 0
  }
}
```

---

## Serialized Resources

Controllers return serialized resources through the standard `data` envelope. ActiveRecord objects are not rendered directly. Each resource blueprint declares its public fields, so database-only fields such as password digests, soft-delete markers, and internal foreign keys are excluded by default.

Timestamps are returned as UTC ISO 8601 strings with millisecond precision. Monetary values must be exposed as integer fields named with the `Minor` suffix, such as `amountMinor`; floating-point amounts are not part of the API contract.

---

## Profile (US-2.5)

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/api/v1/users/me` | Profile of the current user (Bearer access token) |
| PUT | `/api/v1/users/me` | Body `{ "user": { first_name, last_name, phone, birth_date, city, preferred_locale } }`; email cannot be changed |

The profile endpoints moved from `/users/me` to `/api/v1/users/me` (`Api::V1::UsersController`), like every other
endpoint; the old path no longer exists.

---

## Moderation, Blocking and Appeals (EPIC-6)

All `/api/v1/moderation/*` endpoints require a moderator access token (others get `403 FORBIDDEN`, guests `401`).
Every decision is stored in `moderation_logs` (who, when, decision, reason), written to the activity log
(asynchronously, `ActivityLogJob`) and emailed to the affected person in their preferred language (`uk`/`en`).
A reason is required wherever a decision says "reason" below; a missing reason returns
`422 VALIDATION_FAILED` with `details: [{ "field": "reason" }]`. Deciding on an item in the wrong status returns
`409 INVALID_STATUS_TRANSITION`.

| Method | Path | Body | Notes |
| --- | --- | --- | --- |
| GET | `/moderation/organizations?status=pending_approval` | | Queue. `status`: any organization status, `pending` (alias) or `all`. Filter `city`; sort `created_at`, `updated_at` |
| POST | `/moderation/organizations/{id}/approve` | | `pending_approval → approved`; owner is emailed |
| POST | `/moderation/organizations/{id}/reject` | `reason` | `pending_approval → rejected` |
| POST | `/moderation/organizations/{id}/block` | `reason` | Organization and its events are hidden, ticket sales stop, staff cannot create or edit events. Sold tickets stay valid |
| POST | `/moderation/organizations/{id}/unblock` | `reason` (optional) | Back to `approved` (or `pending_approval` if it was never approved); an open appeal is closed |
| GET | `/moderation/events?status=under_review` | | Queue of new events with all translations. Filters `organization_id`, `category_id`; sort `submitted_at`, `created_at`, `start_at` |
| POST | `/moderation/events/{id}/approve` | | `under_review → published`; only for an approved organization; creator is emailed |
| POST | `/moderation/events/{id}/reject` | `reason` | `under_review → rejected` |
| GET | `/moderation/event-revisions?status=under_review` | | Queue of edits of published events (FR-MOD-6). Each item has the `event` (id, title, status, organization), `submitted_by`, the full `proposed` data and `changes`: the changed fields as `{ field, old, new }`, compared with the live event (`null` once decided). `status`: any revision status or `all`. Filter `event_id`; sort `created_at`, `updated_at` |
| POST | `/moderation/event-revisions/{id}/approve` | | `under_review → approved`: the public event is replaced (`Events::Revisions::Apply`). Only while the event is `published` and its organization approved (else `409`); a revision that no longer fits the event (e.g. it removes a ticket type that has sold since) returns `422` and stays pending. Editor is emailed |
| POST | `/moderation/event-revisions/{id}/reject` | `reason` | `under_review → rejected`; the event stays unchanged and the editor is emailed with the reason |
| POST | `/moderation/users/{id}/block` | `reason` | The user's tokens stop working at once; moderators cannot be blocked (`CANNOT_BLOCK_MODERATOR`) |
| POST | `/moderation/users/{id}/unblock` | `reason` (optional) | Restores access; an open appeal is closed |
| GET | `/moderation/appeals?status=open` | | Appeal queue (users and organizations), with the target, its block reason and `blocked_by_id`. Filter `target_type` |
| GET | `/moderation/appeals/{id}` | | One appeal |
| POST | `/moderation/appeals/{id}/accept` | `reason` (optional) | Unblocks the user or restores the organization to `approved` |
| POST | `/moderation/appeals/{id}/reject` | `reason` | The block stays; a new appeal is possible 24 hours later |
| GET | `/moderation/logs` | | Moderation decisions. Filters `entity_type`, `entity_id`, `moderator_id`, `decision` |

Unblocking a user or an organization with `/unblock` also closes its open appeal as accepted.

### Appeals

A blocked user who logs in with correct credentials gets `403 USER_BLOCKED` with the block reason and an appeal
token (valid 24 hours, `JWT_APPEAL_TTL`):

```json
{
  "code": "USER_BLOCKED",
  "message": "Your account has been blocked.",
  "details": [{ "field": "block_reason", "message": "Spam" }],
  "appeal_token": "eyJ...",
  "appeal_token_expires_in": 86400
}
```

The appeal token works only for the endpoints below; any other endpoint answers `403 APPEAL_TOKEN_SCOPE`.
The owner of a blocked organization is not blocked, so they use a normal access token and pass `organization_id`.
Managers cannot appeal.

| Method | Path | Body / query | Notes |
| --- | --- | --- | --- |
| POST | `/appeals` | `message` (1–2000 chars), `organization_id` (organization appeals) | `201` with the appeal. `409 NOT_BLOCKED`, `409 APPEAL_ALREADY_OPEN`, or `429 APPEAL_COOLDOWN` with `details: [{ "field": "next_appeal_allowed_at", "message": "<ISO 8601>" }]` |
| GET | `/appeals/current` | `organization_id` (optional) | Block state, the latest appeal with its decision, `can_submit` and `next_appeal_allowed_at` |

## Subscriptions and Reminders (EPIC-12)

All paths are under `/api/v1`. Every endpoint except the one-click unsubscribe needs a Bearer access token.

| Method | Path | Body / query | Notes |
| --- | --- | --- | --- |
| POST | `/subscriptions` | `target_type` (`event` or `organization`), `target_id` | `201`. `409 SUBSCRIPTION_ALREADY_EXISTS`; `422 SUBSCRIPTION_TARGET_UNAVAILABLE` for an unpublished, cancelled or deleted event, or an organization that is not approved (blocked, pending, rejected) |
| GET | `/subscriptions/my` | `target_type` (optional), `page`, `pageSize` | Own subscriptions with `target_name` in the request locale; sort `created_at` |
| DELETE | `/subscriptions/{id}` | | `204`; `403` for another user's subscription |
| GET | `/subscriptions/unsubscribe` | `token` | Guest. The signed token from the email link; `200 { data: { unsubscribed: true } }`, also when repeated. `422 TOKEN_INVALID` for a tampered token |

Emails (sent through `email_outboxes`, delivered by `Emails::ProcessOutboxJob`, in the recipient's language):

| Trigger | Recipients |
| --- | --- |
| Moderator approves a new event | Organization subscribers |
| Owner/manager updates the public info of an approved organization | Organization subscribers |
| An approved revision changes the date/time, location or ticket prices (`Events::Revisions::Apply`) | Event subscribers and holders of valid tickets |
| Organizer cancels a published event with tickets | Event subscribers and holders of valid tickets |
| Hourly `Events::SendRemindersJob`: event starts within 24 hours | Event subscribers and holders of valid tickets (not organization subscribers) |

A user who both follows an event and holds a ticket gets one email. Blocked, deactivated and deleted users get
nothing. Subscribers get an unsubscribe link (`{FRONTEND_URL}/unsubscribe?token=...`; the frontend calls the endpoint
above). `event_reminders` (unique `event_id` + `user_id`) prevents duplicate reminders and is cleared when an approved
revision moves the start time, so a new reminder goes out for the new date.

### Enforcement helpers for other features

- `Organization.publicly_visible` and `Event.publicly_visible` hide blocked, pending and rejected organizations and
  their events. Public catalogs (EPIC-3, EPIC-4) must build on these scopes.
- `Event#ticket_sales_open?` is false while the organization is blocked; the order flow (EPIC-7) must check it.
- `Organization#accepts_event_changes?` is false while the organization is not approved; event create/edit
  policies (EPIC-5) must check it.
- A blocked user cannot authenticate, so they cannot buy tickets, write reviews or ask questions.

---

## OpenAPI Documentation

Swagger UI is available at `/api-docs`. The OpenAPI document is generated from request specs with:

```bash
cd api
bundle exec rake rswag:specs:swaggerize
```

The generated v1 document is served at `/api-docs/v1/swagger.yaml`. `api/swagger/` is git-ignored, so run the command
after pulling. Generation uses `--dry-run` (no requests are sent), but it still loads `rails_helper`, which checks the
test database schema, so PostgreSQL must be running and the test database prepared (`bin/rails db:test:prepare`).

The document lists two servers: `/` (the host Swagger UI was opened from, so "Try it out" works on `localhost`,
`127.0.0.1` and `0.0.0.0` without CORS) and `http://{host}:{port}` to target a host explicitly. Protected endpoints use
the **Authorize** button (`bearerAuth`): paste the access token or, for the appeal endpoints, the appeal token.

### Writing request specs

Every endpoint is described by a request spec in `spec/requests/` written with the rswag DSL, so it is tested and
documented at the same time:

```ruby
require 'swagger_helper'

RSpec.describe 'Auth: login', type: :request do
  path '/api/v1/auth/login' do
    post 'Log in with email and password' do
      tags 'Auth'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :credentials, in: :body, schema: { type: :object, required: %w[email password] }

      response '401', 'invalid credentials' do
        schema '$ref' => '#/components/schemas/error'
        let(:credentials) { { email: 'nobody@example.com', password: 'wrong-pass1' } }

        run_test! { expect(json['code']).to eq('INVALID_CREDENTIALS') }
      end
    end
  end
end
```

Conventions:

- `run_test!` sends the request in a `before` hook that applies to the whole group, so a group that has `run_test!`
  must not contain other examples or nested groups. Put each `run_test!` in its own `context`.
- To wrap the request in `expect { }`, call `send_documented_request` (from `spec/support/swagger_helpers.rb`) inside
  an `it`: `expect { send_documented_request }.to have_enqueued_mail(UserMailer, :confirmation)`.
- Header and camelCase query parameters use a snake_case getter, e.g.
  `parameter name: 'Authorization', in: :header, type: :string, required: false, getter: :authorization` with
  `let(:authorization) { "Bearer #{token}" }`. Use the string name `'Authorization'`, so rswag merges it with the
  header derived from `security [bearerAuth: []]`.
- Reusable response schemas (`error`, `pagination`, `user_profile`, `appeal`, ...) live in `spec/swagger_helper.rb`.

---

## CORS

Browser access is limited to the origins listed in `FRONTEND_ORIGINS`. Without it, development and test allow
`http://localhost`, `http://127.0.0.1` and `http://0.0.0.0` on port `PORT` (default 3000, the API and Swagger UI) and
on 5173 (the frontend). The value is comma-separated and must include the complete origin, including scheme and port where applicable. The API accepts JSON requests and the `Authorization` and `Idempotency-Key` headers. Production does not permit wildcard origins.

---

## Running the API

To start the local development server, navigate to the API directory and run:

```bash
cd api
rails server