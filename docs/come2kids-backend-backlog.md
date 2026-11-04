# Come2Kids — Backend Backlog

Epics, user stories and tasks for the Come2Kids backend (Ruby on Rails API, PostgreSQL, MongoDB for activity logs, JWT, monobank test acquiring, RSpec, Rubocop).

Source: *Come2Kids — Backend API and Database Technical Requirements*. Requirement IDs (FR-…) in each story point to that document.

## How to use this file

- **Epic** → create a GitHub issue with label `epic` (or a milestone) and keep the story list as a task list.
- **User story** → create an issue with label `story`, link it to its epic, copy the *Acceptance criteria*.
- **Task** → create a sub-issue or a checklist item inside the story issue, label `task`.
- IDs: `EPIC-n`, `US-n.m`, `T-n.m.k`. Priority: **P0** must-have, **P1** should-have, **P2** later phase.
- Suggested labels: `epic`, `story`, `task`, `backend`, `db`, `api`, `security`, `payments`, `email`, `i18n`, `testing`, `P0`, `P1`, `P2`.

## Definition of Done (for every story)

- [ ] Code merged to `main` through a reviewed pull request, Rubocop passes with no offenses.
- [ ] RSpec specs cover the happy path and main error cases; CI is green.
- [ ] Endpoints are documented in OpenAPI/Swagger with request/response examples.
- [ ] Database changes are delivered as ActiveRecord migrations (reversible) and seeds are updated if needed.
- [ ] Authorization is checked on the server (role and ownership) and covered by specs.
- [ ] User-facing messages and emails exist in `uk` and `en`.
- [ ] Relevant user actions are written to the activity log (after EPIC-13 is done).

## Delivery phases

| Phase | Epics |
|---|---|
| 1. Foundation | EPIC-1, EPIC-2 |
| 2. Organizations and events | EPIC-3, EPIC-4, EPIC-5, EPIC-6 (moderation part) |
| 3. Tickets and payments | EPIC-7, EPIC-8, EPIC-9, EPIC-10 |
| 4. Community and engagement | EPIC-11, EPIC-12, EPIC-13, EPIC-14, EPIC-6 (blocking, appeals) |
| 5. Hardening and later features | EPIC-15, EPIC-16 |

---

## EPIC-1: Project Foundation and Infrastructure

**Goal:** a working Rails API project with database, CI, conventions and background processing so that every team member can build features on a stable base.
**Priority:** P0 · **Labels:** `epic`, `backend`

### US-1.1 Rails API skeleton and local environment — P0
As a developer, I want a runnable Rails API project with PostgreSQL, so that the team can start feature work.

**Acceptance criteria**
- `rails new` in API mode, Ruby and Rails versions pinned, project builds from a clean clone.
- Docker Compose starts the Rails app, PostgreSQL and MongoDB with one command.
- Configuration comes from environment variables; `.env.example` is committed, secrets are not.
- `GET /api/v1/health` returns 200 with application and database status.

**Tasks**
- [ ] T-1.1.1 Generate the Rails API app, set the folder structure and `/api/v1` namespace
- [ ] T-1.1.2 Add `Dockerfile` and `docker-compose.yml` (app, PostgreSQL, MongoDB)
- [ ] T-1.1.3 Configure environment variables, Rails credentials and `.env.example`
- [ ] T-1.1.4 Implement the health-check endpoint
- [ ] T-1.1.5 Write README with setup instructions

### US-1.2 CI pipeline and code quality — P0
As a developer, I want automatic checks on every pull request, so that broken or badly formatted code is not merged.

**Acceptance criteria**
- GitHub Actions runs Rubocop and RSpec on every pull request and on `main`.
- Failing checks block merging; a shared `.rubocop.yml` is committed.
- Test coverage report is produced (SimpleCov).

**Tasks**
- [ ] T-1.2.1 Add the GitHub Actions workflow (Rubocop, RSpec, PostgreSQL service)
- [ ] T-1.2.2 Add `.rubocop.yml` agreed by the team and fix existing offenses
- [ ] T-1.2.3 Configure RSpec, FactoryBot, Faker and SimpleCov
- [ ] T-1.2.4 Add a pull request template and branch protection rules
- [ ] T-1.2.5 Configure Jest for any JavaScript tooling in the repository (if applicable)

### US-1.3 API conventions and documentation — P0
As an API consumer, I want a consistent API format, so that the frontend can handle responses and errors uniformly.

**Acceptance criteria**
- Unified error format `{ code, message, details }` with correct HTTP status codes.
- Pagination (`page`, `pageSize`) and sorting/filtering helpers return total count.
- Swagger UI is available and generated from specs (rswag) or annotations.
- All timestamps are UTC ISO 8601; amounts are integers in minor units.

**Tasks**
- [ ] T-1.3.1 Implement a global exception handler and error codes catalog
- [ ] T-1.3.2 Implement pagination and query-filter concerns
- [ ] T-1.3.3 Set up serializers (e.g., Blueprinter or ActiveModelSerializers) and a base response format
- [ ] T-1.3.4 Set up rswag and publish Swagger UI
- [ ] T-1.3.5 Configure CORS

### US-1.4 Background jobs and email infrastructure — P0
As a developer, I want a job queue and a mailer configured, so that emails and scheduled work run outside the request.

**Acceptance criteria**
- Active Job runs with a queue adapter (e.g., Sidekiq) and retries failed jobs.
- A recurring job scheduler is available (used later for reminders and payment checks).
- Emails are sent through ActionMailer; in development they are caught by a local mail catcher.
- Failed emails are retried and logged.

**Tasks**
- [x] T-1.4.1 Configure the queue adapter and its Docker service
- [x] T-1.4.2 Configure the scheduler for recurring jobs
- [x] T-1.4.3 Configure ActionMailer, SMTP settings and a development mail catcher
- [ ] T-1.4.4 Create a base mailer layout (uk/en)

### US-1.5 Database baseline and seeds — P0
As a developer, I want migrations and seed data conventions, so that every environment can be recreated identically.

**Acceptance criteria**
- `rails db:setup` creates the schema and seed data (categories, a moderator account, sample organizations and events).
- Foreign keys, indexes and constraints are defined in migrations as in the requirements (Section 6).
- ER diagram is committed to the repository and updated with schema changes.

**Tasks**
- [ ] T-1.5.1 Create the first migrations for users and tokens
- [ ] T-1.5.2 Write `db/seeds.rb` (categories uk/en, moderator, demo data)
- [ ] T-1.5.3 Create and commit the ER diagram

---

## EPIC-2: Authentication, Authorization and Profile

**Goal:** secure registration and login with JWT, role-based access control and profile management.
**Priority:** P0 · **Labels:** `epic`, `backend`, `security`

### US-2.1 Registration with email confirmation — P0
As a guest, I want to register and confirm my email, so that I can become a verified user. (FR-AUTH-1, 2, 3)

**Acceptance criteria**
- `POST /auth/register` validates email uniqueness and password policy (min 8 chars, a letter and a digit).
- A confirmation email with a single-use, expiring token (24 h) is sent asynchronously.
- `POST /auth/confirm-email` activates the account; expired or used tokens return a clear error.
- `POST /auth/resend-confirmation` is rate-limited.
- Unverified users cannot log in.

**Tasks**
- [ ] T-2.1.1 Create `users` and `email_tokens` tables and models with validations
- [ ] T-2.1.2 Implement password hashing (`has_secure_password`/bcrypt)
- [ ] T-2.1.3 Implement register, confirm and resend endpoints
- [ ] T-2.1.4 Create the confirmation email template (uk/en)
- [ ] T-2.1.5 Write request specs for all error cases (duplicate email, weak password, expired token)

### US-2.2 Login, JWT and refresh tokens — P0
As a user, I want to log in and stay logged in safely. (FR-AUTH-4)

**Acceptance criteria**
- `POST /auth/login` returns a short-lived access token and a long-lived refresh token.
- `POST /auth/refresh` rotates the refresh token; `POST /auth/logout` revokes it.
- Refresh tokens are stored hashed and can be revoked.
- A blocked user receives 403 `USER_BLOCKED` (see EPIC-6, appeals).

**Tasks**
- [ ] T-2.2.1 Create the `refresh_tokens` table and model
- [ ] T-2.2.2 Implement the JWT encode/decode service and authentication middleware
- [ ] T-2.2.3 Implement login, refresh and logout endpoints
- [ ] T-2.2.4 Rate-limit login attempts
- [ ] T-2.2.5 Write specs (valid/invalid credentials, token expiry, revoked token)

### US-2.3 Password reset — P1
As a user, I want to reset a forgotten password. (FR-AUTH-5)

**Acceptance criteria**
- `POST /auth/forgot-password` always responds with the same message (no email enumeration) and sends a reset link.
- `POST /auth/reset-password` accepts a valid single-use token and revokes all refresh tokens.

**Tasks**
- [ ] T-2.3.1 Implement reset token generation and expiry
- [ ] T-2.3.2 Implement both endpoints and the reset email (uk/en)
- [ ] T-2.3.3 Write specs

### US-2.4 Role-based authorization — P0
As the platform, I want every endpoint protected by role and ownership rules, so that users only do what they are allowed to. (Permission matrix, Section 2.1)

**Acceptance criteria**
- Roles: guest, user, organization manager, organization owner, moderator are resolved per request.
- A manager of organization A cannot access organization B's resources.
- Unauthorized requests return 401, forbidden requests return 403.
- A reusable policy layer (e.g., Pundit) is used by all controllers.

**Tasks**
- [ ] T-2.4.1 Add the policy layer and base policy
- [ ] T-2.4.2 Implement current-user and current-organization-role resolution
- [ ] T-2.4.3 Write a shared RSpec example set for authorization checks
- [ ] T-2.4.4 Document the permission matrix in the Swagger description

### US-2.5 Profile management — P1
As a user, I want to view and edit my profile, but not my email. (FR-AUTH-7)

**Acceptance criteria**
- `GET /users/me` and `PUT /users/me` work for any authenticated user.
- Email cannot be changed (ignored or rejected with a clear error).
- Editable fields: first name, last name, phone, birth date, avatar, city, preferred language (`uk`/`en`).

**Tasks**
- [ ] T-2.5.1 Implement the endpoints and strong parameters
- [ ] T-2.5.2 Implement avatar upload through Active Storage (type and size validation)
- [ ] T-2.5.3 Write specs

---

## EPIC-3: Organizations

**Goal:** organizations can be created, approved by moderators, managed by owners and viewed publicly.
**Priority:** P0 · **Labels:** `epic`, `backend`

### US-3.1 Request organization creation — P0
As a verified user, I want to request a new organization, so that I can publish events. (FR-ORG-1, 2, 6)

**Acceptance criteria**
- `POST /organizations` creates an organization with status `PendingApproval` and the requester as owner.
- A user can own only one organization (unique `owner_id`); a second request returns a clear error.
- Name, description (uk required, en optional), contacts and logo are validated.
- Unapproved organizations cannot publish events.

**Tasks**
- [ ] T-3.1.1 Create `organizations` and `organization_translations` tables and models
- [ ] T-3.1.2 Implement the create endpoint and the one-organization-per-owner rule
- [ ] T-3.1.3 Implement logo upload
- [ ] T-3.1.4 Write specs

### US-3.2 Update organization information — P0
As an owner, I want to update my organization's information. (FR-ORG-3)

**Acceptance criteria**
- Only the owner can update; managers receive 403.
- Translations (uk required, en optional) can be edited.
- Changes to a blocked organization are rejected.

**Tasks**
- [ ] T-3.2.1 Implement `PUT /organizations/{id}` with policy checks
- [ ] T-3.2.2 Write specs

### US-3.3 Manage organization managers — P0
As an owner, I want to add and remove managers. (FR-ORG-4)

**Acceptance criteria**
- `POST /organizations/{id}/managers` adds an existing verified user by email; unknown email returns a clear error.
- `DELETE /organizations/{id}/managers/{userId}` removes a manager.
- The owner cannot be added as a manager of the same organization; managers cannot manage other managers.
- A user can be a manager in several organizations.

**Tasks**
- [ ] T-3.3.1 Create the `organization_managers` table (composite key)
- [ ] T-3.3.2 Implement list/add/remove endpoints
- [ ] T-3.3.3 Send a notification email to the added user (uk/en)
- [ ] T-3.3.4 Write specs

### US-3.4 Public organization page — P1
As a guest, I want to see an organization's profile, events and rating. (FR-ORG-5)

**Acceptance criteria**
- `GET /organizations` and `GET /organizations/{id}` return only approved, non-blocked organizations.
- Response includes translated info, average rating, published events count.
- Content is returned in the requested language with fallback to Ukrainian.

**Tasks**
- [ ] T-3.4.1 Implement list and detail endpoints with serializers
- [ ] T-3.4.2 Implement search by name
- [ ] T-3.4.3 Write specs

---

## EPIC-4: Public Event Catalog

**Goal:** guests and users can browse and search published events.
**Priority:** P0 · **Labels:** `epic`, `backend`, `api`

### US-4.1 List and filter published events — P0
As a guest, I want to browse events with filters, so that I can find something interesting. (FR-EVT-1, 2)

**Acceptance criteria**
- `GET /events` returns only `Published`, non-blocked-organization events.
- Filters: date range, category, city/online, price range (including free), organization, text search by title in the requested language.
- Sorting by date, price and popularity; pagination with total count.
- List responds in under 500 ms for 10,000 events (indexes verified with `EXPLAIN`).

**Tasks**
- [ ] T-4.1.1 Create `events`, `event_translations`, `categories`, `event_images` tables and models
- [ ] T-4.1.2 Implement the query object with filters and sorting
- [ ] T-4.1.3 Add database indexes and check query plans
- [ ] T-4.1.4 Implement the endpoint and serializer
- [ ] T-4.1.5 Seed 10,000 events for a performance check
- [ ] T-4.1.6 Write specs for every filter and for hidden statuses

### US-4.2 Event details — P0
As a guest, I want to see full event details. (FR-EVT-3, 4)

**Acceptance criteria**
- `GET /events/{id}` returns translated texts, images, category, dates and time zone, location or online link, organization summary, ticket types with price and remaining availability, average rating.
- Unpublished events return 404 for the public.
- Past events are marked as finished and cannot be bought.

**Tasks**
- [ ] T-4.2.1 Implement the endpoint and serializer
- [ ] T-4.2.2 Compute availability (total minus sold) in one query
- [ ] T-4.2.3 Write specs

### US-4.3 Categories — P1
As a guest, I want a list of categories to filter by.

**Acceptance criteria**
- `GET /categories` returns categories with `name_uk` and `name_en`, localized by the request language.

**Tasks**
- [ ] T-4.3.1 Implement the endpoint and seed categories
- [ ] T-4.3.2 Write specs

---

## EPIC-5: Event Management and Lifecycle

**Goal:** owners and managers can create, edit, submit and cancel events following the status workflow, including re-moderation through revisions.
**Priority:** P0 · **Labels:** `epic`, `backend`

### US-5.1 Create a draft event — P0
As an owner or manager, I want to create an event with ticket types, so that I can prepare it for publication. (FR-EM-1, 2, 6, 7)

**Acceptance criteria**
- `POST /organizations/{orgId}/events` creates an event in `Draft` with translations (uk required, en optional).
- Ticket types have a name, price (0 = free) and a fixed quantity greater than 0.
- Validation: end after start, time zone present, location or online link present.
- Only members of an approved, non-blocked organization can create events.

**Tasks**
- [ ] T-5.1.1 Create the `ticket_types` table and model (check constraints on quantity and price)
- [ ] T-5.1.2 Implement the create endpoint with nested translations and ticket types
- [ ] T-5.1.3 Implement the policy (owner/manager of this organization only)
- [ ] T-5.1.4 Write specs

### US-5.2 Event media upload — P1
As an organizer, I want to upload a banner and gallery images. (Pending status in wizard)

**Acceptance criteria**
- `POST /organizations/{orgId}/events/{id}/images` accepts images (type and size limits) and stores them with Active Storage.
- Images can be reordered and deleted while the event is not under review.

**Tasks**
- [ ] T-5.2.1 Implement upload, reorder and delete endpoints
- [ ] T-5.2.2 Validate content type, size and count
- [ ] T-5.2.3 Write specs

### US-5.3 Event status workflow — P0
As an organizer, I want to submit a draft for moderation and track its status. (Section 4)

**Acceptance criteria**
- A state machine enforces the allowed transitions (Draft, Under Review, Published, Rejected, Cancelled by Organizer, Failed handling as documented).
- `POST …/events/{id}/submit` validates all required fields and moves the event to `Under Review`; invalid events return field errors.
- Every transition is stored in `event_status_histories` (who, when, reason, error code).
- Events under review cannot be edited.

**Tasks**
- [ ] T-5.3.1 Create the `event_status_histories` table
- [ ] T-5.3.2 Implement the state machine (e.g., AASM or a service object) with guards
- [ ] T-5.3.3 Implement the submit endpoint and completeness validation
- [ ] T-5.3.4 Document the transition diagram in the repository
- [ ] T-5.3.5 Write specs for every allowed and forbidden transition

### US-5.4 Edit a published event through a revision — P0
As an organizer, I want to edit a published event without hiding it, so that sales continue while moderators review my changes. (FR-EM-3, 8, 9)

**Acceptance criteria**
- Editing a `Published` event creates one pending `EventRevision`; the public version stays unchanged and tickets stay on sale.
- Only one pending revision per event (partial unique index); it can be edited or withdrawn.
- Ticket quantity cannot go below sold tickets; prices of sold tickets do not change.
- On approval (EPIC-6) the revision data replaces the public version in one transaction.

**Tasks**
- [ ] T-5.4.1 Create the `event_revisions` table (JSONB payload, status, reviewer, reason)
- [ ] T-5.4.2 Implement revision create/update/withdraw endpoints
- [ ] T-5.4.3 Implement the service that applies an approved revision atomically
- [ ] T-5.4.4 Clear reminder records if the start time changed
- [ ] T-5.4.5 Write specs including concurrent edits

### US-5.5 Cancel or delete an event — P0
As an organizer, I want to cancel or delete an event. (FR-EM-4)

**Acceptance criteria**
- An event without sold tickets can be soft-deleted.
- An event with sold tickets is moved to `Cancelled by Organizer`; ticket holders and subscribers get an email; no automatic refund.
- Cancelled events accept no new orders.

**Tasks**
- [ ] T-5.5.1 Implement `DELETE …/events/{id}` logic for both cases
- [ ] T-5.5.2 Implement the cancellation notification job
- [ ] T-5.5.3 Write specs

### US-5.6 Organizer event list and participants — P1
As an organizer, I want to see all my events in any status and who bought tickets. (FR-EM-5)

**Acceptance criteria**
- `GET /organizations/{orgId}/events` lists events of all statuses with a pending-revision flag.
- `GET …/events/{id}/tickets` lists sold tickets with holder name, ticket type and check-in state; supports pagination and search.

**Tasks**
- [ ] T-5.6.1 Implement both endpoints with filters
- [ ] T-5.6.2 Write specs

---

## EPIC-6: Moderation, Blocking and Appeals

**Goal:** moderators control what is published and can block users and organizations; blocked parties can appeal.
**Priority:** P0 (moderation), P1 (blocking, appeals) · **Labels:** `epic`, `backend`

### US-6.1 Organization moderation — P0
As a moderator, I want to approve or reject new organizations. (FR-ORG-2, FR-MOD-1, 2, 3)

**Acceptance criteria**
- `GET /moderation/organizations?status=pending` lists the queue.
- Approve/reject endpoints require the moderator role; rejection needs a reason.
- The owner gets an email (uk/en); the decision is written to `moderation_logs`.

**Tasks**
- [ ] T-6.1.1 Create the `moderation_logs` table
- [ ] T-6.1.2 Implement queue and decision endpoints
- [ ] T-6.1.3 Implement the decision email
- [ ] T-6.1.4 Write specs

### US-6.2 Event and revision moderation — P0
As a moderator, I want to review new events and edits of published events. (FR-MOD-2, 6)

**Acceptance criteria**
- Separate queues for new events and for revisions; revisions show old and new values.
- Approve publishes the event (or applies the revision); reject requires a reason and notifies the editor.
- After approval, subscribers and ticket holders are notified when public data changed.

**Tasks**
- [ ] T-6.2.1 Implement event queue and decision endpoints
- [ ] T-6.2.2 Implement revision queue, diff serializer and decision endpoints
- [ ] T-6.2.3 Trigger notification jobs after approval
- [ ] T-6.2.4 Write specs

### US-6.3 Block and unblock users — P1
As a moderator, I want to block abusive users. (FR-MOD-4, 7)

**Acceptance criteria**
- `POST /moderation/users/{id}/block` requires a reason, sets block fields and revokes refresh tokens.
- A blocked user cannot log in, buy tickets, review or ask questions.
- Moderators cannot block other moderators; unblock restores access.
- The user receives an email with the reason; the action is logged.

**Tasks**
- [ ] T-6.3.1 Add block fields to users and enforce them in authentication and policies
- [ ] T-6.3.2 Implement block/unblock endpoints
- [ ] T-6.3.3 Implement the notification email
- [ ] T-6.3.4 Write specs

### US-6.4 Block and unblock organizations — P1
As a moderator, I want to block an organization. (FR-MOD-5, 7)

**Acceptance criteria**
- A blocked organization and its events disappear from public lists; sales stop; owner and managers cannot create or edit events.
- Sold tickets stay valid and are not refunded automatically.
- Unblocking restores visibility and sales.

**Tasks**
- [ ] T-6.4.1 Implement block/unblock endpoints and status handling
- [ ] T-6.4.2 Apply the blocked-organization filter in catalog queries and the order flow
- [ ] T-6.4.3 Implement the owner notification email
- [ ] T-6.4.4 Write specs

### US-6.5 Appeals of blocked users and organizations — P1
As a blocked user or the owner of a blocked organization, I want to appeal. (FR-APP-1…7)

**Acceptance criteria**
- A blocked user who logs in with correct credentials gets 403 `USER_BLOCKED`, the reason and a short-lived appeal token limited to appeal endpoints.
- The owner of a blocked organization appeals with a normal login.
- One open appeal per blocked user or organization; after a rejection, a new appeal is accepted only after 24 hours (error contains the allowed time).
- Moderators work in a separate appeals queue; accepting unblocks; rejecting needs a reason; the appellant is notified.

**Tasks**
- [ ] T-6.5.1 Create the `appeals` table (target type/id, status, reviewer, reason)
- [ ] T-6.5.2 Implement the appeal-token flow and the `/appeals` endpoints
- [ ] T-6.5.3 Implement the cooldown rule
- [ ] T-6.5.4 Implement the moderator queue and decision endpoints
- [ ] T-6.5.5 Implement notification emails (uk/en)
- [ ] T-6.5.6 Write specs

---

## EPIC-7: Orders and Tickets

**Goal:** users can order tickets for paid and free events without overselling.
**Priority:** P0 · **Labels:** `epic`, `backend`, `db`

### US-7.1 Create an order with ticket reservation — P0
As a user, I want to order tickets, so that they are reserved for me. (FR-TKT-1, 2, 7)

**Acceptance criteria**
- `POST /events/{id}/orders` accepts ticket type and quantity, supports an `Idempotency-Key` header.
- Availability check and reservation are atomic; concurrent requests never oversell (verified by a concurrency spec).
- No per-user ticket limit; sold-out returns a clear error code.
- Orders are rejected for unpublished, cancelled, started or blocked-organization events and for blocked users.
- The order gets `reserved_until` equal to the payment validity (default 15 minutes).

**Tasks**
- [ ] T-7.1.1 Create `orders`, `order_items`, `tickets` tables and models (check constraint `sold_quantity <= total_quantity`)
- [ ] T-7.1.2 Implement the order service with row locking or optimistic concurrency
- [ ] T-7.1.3 Implement idempotency handling
- [ ] T-7.1.4 Implement the endpoint and serializers
- [ ] T-7.1.5 Write a multi-threaded spec that tries to oversell

### US-7.2 Free ticket orders — P0
As a user, I want to get free tickets without payment. (FR-TKT-3, FR-PAY-9)

**Acceptance criteria**
- Orders with total 0 skip monobank: status becomes `Paid` immediately and tickets are issued at once.
- The confirmation email with PDF is sent (EPIC-8).

**Tasks**
- [ ] T-7.2.1 Branch the order service for free orders
- [ ] T-7.2.2 Write specs

### US-7.3 Release expired reservations — P0
As the platform, I want unpaid reservations to expire, so that tickets return to sale.

**Acceptance criteria**
- A recurring job releases reservations of `Pending` orders after `reserved_until` and marks them `Expired`.
- Released quantities are returned to `ticket_types` atomically.

**Tasks**
- [ ] T-7.3.1 Implement the expiry job and schedule it
- [ ] T-7.3.2 Write specs

### US-7.4 My orders and tickets — P0
As a user, I want to see my orders and tickets. (FR-TKT-6)

**Acceptance criteria**
- `GET /orders/my`, `GET /orders/{id}`, `GET /tickets/my`, `GET /tickets/{id}` return only the caller's data.
- Order responses include the current payment status.

**Tasks**
- [ ] T-7.4.1 Implement the endpoints with ownership policies
- [ ] T-7.4.2 Write specs (including access to someone else's ticket)

---

## EPIC-8: monobank Payments

**Goal:** paid tickets are purchased through monobank acquiring (test environment, one shared token).
**Priority:** P0 · **Labels:** `epic`, `backend`, `payments`

### US-8.1 monobank client and configuration — P0
As a developer, I want a monobank API client behind an interface, so that payments can be stubbed in tests. (FR-PAY-1)

**Acceptance criteria**
- A `Payments::Monobank::Client` wraps invoice create/status and public-key calls with the `X-Token` header from environment variables.
- HTTP 429 and network errors are retried with backoff.
- The client is stubbed in all specs (WebMock/VCR); no real calls in CI.
- Test-environment behavior (any card passing the Luhn check) is documented in the README.

**Tasks**
- [ ] T-8.1.1 Implement the client and a fake implementation for specs
- [ ] T-8.1.2 Store the shared test token in environment variables / team secret store
- [ ] T-8.1.3 Add timeouts, retries and logging without leaking secrets
- [ ] T-8.1.4 Document the local webhook setup (tunnel) in the README

### US-8.2 Create an invoice for a paid order — P0
As a user, I want to be redirected to the monobank payment page. (FR-PAY-2)

**Acceptance criteria**
- After the reservation the backend calls invoice create with amount in kopecks, `ccy` 980, `redirectUrl`, `webHookUrl` and `validity` equal to the reservation time.
- `invoiceId` and `pageUrl` are saved in `payments`; the order response contains `pageUrl`.
- A failed invoice creation releases the reservation and returns a clear error.

**Tasks**
- [ ] T-8.2.1 Create the `payments` table and model
- [ ] T-8.2.2 Integrate invoice creation into the order service
- [ ] T-8.2.3 Allow retry with a new invoice while the reservation is valid
- [ ] T-8.2.4 Write specs with the fake client

### US-8.3 Webhook endpoint with signature verification — P0
As the platform, I want to receive payment results securely. (FR-PAY-3, 4)

**Acceptance criteria**
- `POST /payments/monobank/webhook` verifies the signature with the monobank public key and rejects invalid requests.
- The handler is idempotent, ignores webhooks older than the stored `modifiedDate`, and responds 200 quickly (heavy work in a job).
- Public key is cached and refreshed when verification fails.

**Tasks**
- [ ] T-8.3.1 Implement signature verification and key caching
- [ ] T-8.3.2 Implement the webhook controller and the processing job
- [ ] T-8.3.3 Handle out-of-order and duplicate webhooks
- [ ] T-8.3.4 Write specs with signed and unsigned payloads

### US-8.4 Payment status mapping and ticket issuing — P0
As a user, I want my tickets issued only after a successful payment. (FR-PAY-6, 7)

**Acceptance criteria**
- `success` → order `Paid`, tickets issued, confirmation email sent; `failure` → `Failed`, reservation released, `errCode` and `failureReason` stored; `expired` → `Expired`, reservation released.
- Status changes are transactional and idempotent.

**Tasks**
- [ ] T-8.4.1 Implement the status mapping service
- [ ] T-8.4.2 Issue tickets and trigger the email job on `success`
- [ ] T-8.4.3 Write specs for every status

### US-8.5 Payment reconciliation — P1
As the platform, I want to recover from missed webhooks. (FR-PAY-5)

**Acceptance criteria**
- A recurring job checks `Pending` payments through the invoice status endpoint and applies the same mapping.
- Order status endpoint can be polled by the client.

**Tasks**
- [ ] T-8.5.1 Implement and schedule the reconciliation job
- [ ] T-8.5.2 Write specs

---

## EPIC-9: Ticket Documents and Email Notifications

**Goal:** every ticket has a QR code and a PDF, and the platform sends the required emails in the user's language.
**Priority:** P0 · **Labels:** `epic`, `backend`, `email`

### US-9.1 Ticket QR code — P0
As a user, I want each ticket to contain a QR code. (FR-TKT-5)

**Acceptance criteria**
- Each ticket has a unique, unguessable `qr_token` (no personal data).
- `GET /tickets/{id}/qr` returns the QR image (PNG or SVG) for the ticket owner only.

**Tasks**
- [ ] T-9.1.1 Generate tokens when tickets are issued (unique index)
- [ ] T-9.1.2 Implement QR image generation (e.g., rqrcode)
- [ ] T-9.1.3 Implement the endpoint and policy
- [ ] T-9.1.4 Write specs

### US-9.2 PDF ticket — P0
As a user, I want to download my ticket as a PDF. (FR-TKT-6)

**Acceptance criteria**
- `GET /tickets/{id}/pdf` returns a PDF with event title, date/time, location, ticket type, holder name, ticket code and QR code, in the user's language.
- PDF generation does not block other requests for long (profile and cache if needed).

**Tasks**
- [ ] T-9.2.1 Design the PDF template (e.g., Prawn)
- [ ] T-9.2.2 Implement the PDF service and endpoint
- [ ] T-9.2.3 Write specs (content smoke test, access control)

### US-9.3 Purchase confirmation email — P0
As a buyer, I want an email with order information and PDF tickets. (FR-TKT-4)

**Acceptance criteria**
- Sent asynchronously after a paid or free order is completed, with PDF tickets attached.
- Email failures never roll back the purchase and are retried (outbox or job retries).

**Tasks**
- [ ] T-9.3.1 Create the mailer and templates (uk/en)
- [ ] T-9.3.2 Implement the job with retries
- [ ] T-9.3.3 Write specs

### US-9.4 Transactional email catalog — P1
As the platform, I want consistent email templates for all notifications. (Section 3.9)

**Acceptance criteria**
- Templates exist in `uk` and `en` for: registration, password reset, organization decision, event decision, revision decision, event cancelled/changed, new event from a followed organization, reminder, question answered, block/unblock, appeal decision, ownership transfer.
- Language is chosen from the recipient's preferred language, default `uk`.

**Tasks**
- [ ] T-9.4.1 Create the shared layout and a mailer per domain
- [ ] T-9.4.2 Write translations in `uk.yml` and `en.yml`
- [ ] T-9.4.3 Add mailer previews and specs

---

## EPIC-10: Ticket Check-in (QR Scanning)

**Goal:** organizers can validate tickets at the entrance.
**Priority:** P0 · **Labels:** `epic`, `backend`

### US-10.1 Check-in endpoint — P0
As an organizer, I want to scan a ticket QR code and see if it is valid. (FR-CHK-1…4)

**Acceptance criteria**
- `POST /organizations/{orgId}/events/{id}/check-in` accepts the decoded token.
- Checks: token exists, ticket belongs to this event, event belongs to the caller's organization, event not cancelled, ticket `Valid`.
- Success marks the ticket `Used`, saves `used_at` and `checked_in_by`, returns holder name and ticket type.
- Error codes: 404 unknown token, 422 other event or cancelled, 409 already used (with first check-in time).
- Two simultaneous scans of one ticket: only one succeeds.

**Tasks**
- [ ] T-10.1.1 Implement the check-in service with a conditional update
- [ ] T-10.1.2 Implement the endpoint and policy
- [ ] T-10.1.3 Write specs including a concurrency spec

### US-10.2 Check-in statistics — P1
As an organizer, I want to see how many visitors have arrived. (FR-CHK-5)

**Acceptance criteria**
- `GET …/events/{id}/check-in/stats` returns sold, checked-in and remaining counts per ticket type.

**Tasks**
- [ ] T-10.2.1 Implement the endpoint
- [ ] T-10.2.2 Write specs

---

## EPIC-11: Reviews and Q&A

**Goal:** attendees can rate events and organizations; users can ask questions and get answers.
**Priority:** P1 · **Labels:** `epic`, `backend`

### US-11.1 Event reviews — P1
As an attendee, I want to review an event I attended. (FR-REV-1, 3)

**Acceptance criteria**
- `POST /events/{id}/reviews` is allowed only with a ticket for the event and after it has ended; one review per user and event.
- Rating 1–5 and optional text; author can edit and delete.
- `GET /events/{id}/reviews` is public with pagination.

**Tasks**
- [ ] T-11.1.1 Create `event_reviews` (unique `event_id`+`user_id`)
- [ ] T-11.1.2 Implement the eligibility service and endpoints
- [ ] T-11.1.3 Write specs

### US-11.2 Organization reviews — P1
As an attendee, I want to review an organization. (FR-REV-2, 3)

**Acceptance criteria**
- Allowed if the user attended at least one finished event of the organization; one review per user and organization.

**Tasks**
- [ ] T-11.2.1 Create `organization_reviews` and the eligibility rule
- [ ] T-11.2.2 Implement endpoints
- [ ] T-11.2.3 Write specs

### US-11.3 Rating aggregation — P1
As a visitor, I want to see average ratings. (FR-REV-4)

**Acceptance criteria**
- Event and organization average rating and count are exposed in list and detail responses and stay consistent after create/edit/delete.

**Tasks**
- [ ] T-11.3.1 Implement counter/average caching with callbacks or a service
- [ ] T-11.3.2 Write specs

### US-11.4 Questions and answers — P1
As a user, I want to ask questions about an event, an organization or the platform. (FR-QA-1…5)

**Acceptance criteria**
- Users ask questions on events and organizations; owners/managers answer their organization's questions; moderators answer platform questions.
- Questions and answers are public; authors can delete their questions; staff can hide inappropriate content.
- The question author gets an email when answered.

**Tasks**
- [ ] T-11.4.1 Create `questions` and `answers` tables
- [ ] T-11.4.2 Implement list/create/answer/hide endpoints with policies
- [ ] T-11.4.3 Implement the answer notification
- [ ] T-11.4.4 Write specs

---

## EPIC-12: Subscriptions and Reminders

**Goal:** users can follow events and organizations and receive notifications and reminders.
**Priority:** P1 · **Labels:** `epic`, `backend`, `email`

### US-12.1 Subscribe and unsubscribe — P1
As a user, I want to follow events and organizations. (FR-SUB-1, 5)

**Acceptance criteria**
- `POST /subscriptions`, `DELETE /subscriptions/{id}`, `GET /subscriptions/my`; unique per user and target.
- Not possible for unpublished events or blocked organizations.
- `GET /subscriptions/unsubscribe?token=…` unsubscribes from an email link without login.

**Tasks**
- [ ] T-12.1.1 Create the `subscriptions` table (unique index)
- [ ] T-12.1.2 Implement endpoints and the signed unsubscribe token
- [ ] T-12.1.3 Write specs

### US-12.2 Change notifications — P1
As a subscriber, I want to know when something changes. (FR-SUB-2, 3, 4)

**Acceptance criteria**
- Organization subscribers get an email when a new event is published or the organization info changes.
- Event subscribers and ticket holders get an email when an approved change affects date, time, location or price, and when the event is cancelled.
- Emails are sent only after the change is public, asynchronously, in the user's language, with an unsubscribe link; blocked users get nothing.

**Tasks**
- [ ] T-12.2.1 Implement notification services triggered by approval and cancellation events
- [ ] T-12.2.2 Implement batching for large audiences
- [ ] T-12.2.3 Write specs

### US-12.3 Event reminder one day before — P1
As a subscriber or ticket holder, I want a reminder before the event. (FR-REM-1…4)

**Acceptance criteria**
- A recurring job (at least hourly) finds published events starting within 24 hours and emails event subscribers and ticket holders; a user who is both gets one email.
- `event_reminders` (unique `event_id`+`user_id`) prevents duplicates; events approved late are handled on the next run.
- No reminders for cancelled, blocked or unpublished events; reminders are cleared if the start time changes.
- Organization subscribers do not receive reminders.

**Tasks**
- [ ] T-12.3.1 Create the `event_reminders` table
- [ ] T-12.3.2 Implement and schedule the reminder job
- [ ] T-12.3.3 Create the reminder email (uk/en)
- [ ] T-12.3.4 Write specs with time travel (e.g., `travel_to`)

---

## EPIC-13: Localization (Ukrainian and English)

**Goal:** the API, emails, PDFs and content support `uk` (default) and `en`.
**Priority:** P0 (infrastructure), P1 (content) · **Labels:** `epic`, `backend`, `i18n`

### US-13.1 Locale resolution and translated messages — P0
As a client, I want to choose the language of API responses. (FR-I18N-1, 2, 3)

**Acceptance criteria**
- Locale comes from `Accept-Language` or a `locale` parameter; default is `uk`; unsupported values fall back to `uk`.
- Validation messages, errors, emails and PDF tickets use the locale; error `code` values never change.

**Tasks**
- [ ] T-13.1.1 Implement locale detection in a base controller concern
- [ ] T-13.1.2 Create `config/locales/uk.yml` and `en.yml` structure
- [ ] T-13.1.3 Add a spec that fails when a key exists in one language only
- [ ] T-13.1.4 Write specs

### US-13.2 Translated content — P1
As an organizer, I want to provide texts in Ukrainian and optionally in English. (FR-I18N-4, 5)

**Acceptance criteria**
- Events, organizations and categories use translation tables or columns; `uk` is required, `en` optional.
- If an English text is missing, the API returns the Ukrainian text.
- Search by title works in the requested language.

**Tasks**
- [ ] T-13.2.1 Implement translation models and a fallback helper
- [ ] T-13.2.2 Apply translations in serializers and search
- [ ] T-13.2.3 Write specs

---

## EPIC-14: Activity Logging (MongoDB)

**Goal:** store user activity logs for audit and troubleshooting.
**Priority:** P1 · **Labels:** `epic`, `backend`

### US-14.1 MongoDB integration and log service — P1
As a developer, I want a simple service to write activity logs. (FR-LOG-2, 3)

**Acceptance criteria**
- Mongoid is configured; collection `activity_logs` has indexes on (user_id, timestamp), (action, timestamp), (entity_type, entity_id).
- `ActivityLogger.log(...)` writes asynchronously and never fails the request.
- Passwords, tokens and card data are never stored; an optional TTL index is configurable.

**Tasks**
- [ ] T-14.1.1 Configure Mongoid and the Docker service
- [ ] T-14.1.2 Implement the document model and indexes
- [ ] T-14.1.3 Implement the async logger service with request context (user, role, IP, user agent, request id)
- [ ] T-14.1.4 Add a sensitive-field filter and specs

### US-14.2 Instrument user actions — P1
As an auditor, I want key actions logged. (FR-LOG-1)

**Acceptance criteria**
- Logged: registration, confirmation, login success/failure, logout, token refresh, password reset, profile update, orders, payment status changes, ticket download, reviews, questions, organization and event changes, status transitions, moderation decisions, blocks, appeals, manager changes, check-ins.
- Action names follow a convention (e.g., `user.login`, `order.paid`).

**Tasks**
- [ ] T-14.2.1 Define the action catalog
- [ ] T-14.2.2 Add log calls through controller concerns and service objects
- [ ] T-14.2.3 Write specs that assert the log entries

### US-14.3 Activity log search for moderators — P1
As a moderator, I want to search logs. (FR-LOG-4)

**Acceptance criteria**
- `GET /moderation/activity-logs` supports filters (user, action, entity, date range), sorting and pagination; other roles get 403.

**Tasks**
- [ ] T-14.3.1 Implement the endpoint and query object
- [ ] T-14.3.2 Write specs

### US-14.4 Application logging — P2
As a developer, I want structured application logs. (FR-LOG-5)

**Acceptance criteria**
- Rails logs are JSON with a request id and log levels; no personal or payment data.

**Tasks**
- [ ] T-14.4.1 Configure the JSON formatter and request id propagation
- [ ] T-14.4.2 Add log filtering for sensitive parameters

---

## EPIC-15: Ownership Transfer (later phase)

**Goal:** an organization owner can hand over ownership.
**Priority:** P2 · **Labels:** `epic`, `backend`

### US-15.1 Transfer organization ownership — P2
As an owner, I want to transfer ownership to another user. (FR-ORG-8)

**Acceptance criteria**
- Owner starts a transfer by recipient email; the recipient must be verified and must not own another organization.
- The recipient accepts or declines within 7 days; the owner can cancel; one pending transfer per organization.
- On acceptance (atomic): the recipient becomes owner and stops being a manager of this organization, the previous owner becomes a manager and can later be removed by the new owner.
- Both parties are notified; everything is logged.

**Tasks**
- [ ] T-15.1.1 Create the `ownership_transfers` table (partial unique index for pending)
- [ ] T-15.1.2 Implement start/accept/decline/cancel endpoints
- [ ] T-15.1.3 Implement the expiry job and emails
- [ ] T-15.1.4 Write specs

---

## EPIC-16: Quality, Security and Delivery

**Goal:** the product is secure, tested, documented and deployable.
**Priority:** P1 · **Labels:** `epic`, `backend`, `security`, `testing`

### US-16.1 Security hardening — P1
As the platform owner, I want protection against common attacks.

**Acceptance criteria**
- Rate limiting on login, registration, resend-confirmation, order creation and appeals (e.g., Rack::Attack).
- Strong parameters everywhere; no raw SQL with user input; XSS-safe serialization.
- HTTPS-only cookies/headers configuration, secrets only in environment variables, dependency scanning (Bundler Audit, Brakeman) in CI.

**Tasks**
- [ ] T-16.1.1 Configure Rack::Attack rules
- [ ] T-16.1.2 Add Brakeman and Bundler Audit to CI
- [ ] T-16.1.3 Review authorization coverage endpoint by endpoint
- [ ] T-16.1.4 Write specs for throttling

### US-16.2 Test strategy and coverage — P1
As a team, we want reliable tests.

**Acceptance criteria**
- At least 70% coverage of services; critical flows covered end to end: registration → login, create/submit/approve event, order → payment webhook → ticket → email, check-in, revision approval.
- External services (monobank, email) are always stubbed.

**Tasks**
- [ ] T-16.2.1 Create factories for all models
- [ ] T-16.2.2 Write request-level flow specs for the critical paths
- [ ] T-16.2.3 Add coverage thresholds in CI

### US-16.3 Documentation and delivery — P1
As a new team member or reviewer, I want complete documentation.

**Acceptance criteria**
- README with setup, environment variables, test commands, monobank test notes and webhook tunnel instructions.
- OpenAPI documentation is complete and matches the implementation.
- ER diagram, status-machine diagram and an architecture overview are committed.
- Docker Compose runs the full backend stack.

**Tasks**
- [ ] T-16.3.1 Finalize README and contributing guide
- [ ] T-16.3.2 Complete Swagger examples and error responses
- [ ] T-16.3.3 Update ER and state diagrams
- [ ] T-16.3.4 Run a demo scenario checklist before the final presentation

---

## Dependency overview

1. EPIC-1 → everything else.
2. EPIC-2 (authentication, authorization) → EPIC-3 … EPIC-16.
3. EPIC-3 and EPIC-4 tables → EPIC-5 → EPIC-6 (moderation) → public catalog shows real data.
4. EPIC-5 (events and ticket types) → EPIC-7 → EPIC-8 → EPIC-9 → EPIC-10.
5. EPIC-13 (US-13.1) should start early, because all emails and messages depend on locale handling.
6. EPIC-14 can start after EPIC-2; instrumentation is added gradually as features appear.
7. EPIC-12 depends on EPIC-6 (approval events) and EPIC-9 (emails); EPIC-15 depends on EPIC-3.
