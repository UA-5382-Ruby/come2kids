# Come2Kids - Frontend Specification

## 1. Project Overview

Come2Kids is an event ticketing platform that allows users to discover events, explore event details, and purchase tickets online.

The frontend is built with React and communicates with a backend API built with Ruby on Rails. PostgreSQL is used for persistent data storage on the backend.

The primary goal is to provide a simple, responsive, and intuitive experience for browsing events and purchasing tickets.

## 2. Technology Stack

- **React** — component-based user interface.
- **TypeScript** — static type checking.
- **Vite** — development server and build tooling.
- **React Router** — client-side navigation.
- **CSS Modules or Tailwind CSS** — styling and responsive layouts.
- **Fetch API or Axios** — HTTP communication with the backend.
- **React Testing Library and Vitest** — component and interaction testing.

The final choice of libraries should match the existing repository configuration.

## 3. Core Features

### 3.1 Event Discovery

Users should be able to browse available events.

Features:
- Display a list of upcoming events.
- Show event cards with a title, image, date, venue, location, and starting price.
- Search events by name or keyword.
- Filter events by category, date, or location.
- Sort events by date or price.
- Display an appropriate empty state when no events match the selected filters.

### 3.2 Event Details

Each event should have a dedicated details page.

The page should display:
- Event title and promotional image.
- Description and category.
- Date and start time.
- Venue and address.
- Available ticket types and prices.
- Remaining availability, when provided by the API.
- A call-to-action button to purchase tickets.

The frontend must display availability based on backend data rather than assuming that tickets are available.

### 3.3 Ticket Selection

Users should be able to select a ticket type and quantity before proceeding to checkout.

Requirements:
- Display available ticket categories and prices.
- Allow users to select a valid quantity.
- Calculate the subtotal based on the selected tickets.
- Prevent quantities below one or above the permitted limit.
- Display a clear message when tickets are unavailable.
- Revalidate availability on the backend before confirming a purchase.

### 3.4 Checkout

The checkout page should summarize the selected event and tickets.

Features:
- Display event details and selected ticket quantities.
- Show the subtotal and any applicable fees.
- Collect the customer information required by the backend.
- Validate required fields.
- Submit the order to the API.
- Display loading, success, and error states.

Payment processing must be handled through a secure payment integration. The frontend must not store raw card details or treat a client-side success message as proof of payment.

### 3.5 User Account

If account functionality is included, users should be able to:
- Register and sign in.
- View their profile.
- Access their order history.
- View purchased tickets.
- Access ticket details or QR codes when supported by the backend.

Users must only be able to access their own orders and tickets.

### 3.6 Order Confirmation

After a successful purchase, users should see a confirmation page containing:
- Order reference.
- Event name and date.
- Purchased ticket types and quantities.
- Payment status, where available.
- Ticket access instructions.

The page should obtain the authoritative order status from the backend.

## 4. Application Pages

| Route | Page | Purpose |
|---|---|---|
| `/` | Home | Featured events and event discovery |
| `/events` | Event Listing | Browse, search, and filter events |
| `/events/:id` | Event Details | View event information and select tickets |
| `/checkout` | Checkout | Review the order and initiate payment |
| `/checkout/success` | Order Confirmation | Display the confirmed order |
| `/login` | Login | Authenticate an existing user |
| `/register` | Registration | Create an account |
| `/account` | Account | Manage profile information |
| `/account/orders` | Order History | View previous purchases |
| `/account/orders/:id` | Order Details | View an individual order |

These routes are proposed. Implement only the pages supported by the project's scope and backend API.

## 5. Component Architecture

Organize the frontend into reusable components and feature-specific modules.

Suggested structure:

```text
src/
├── app/
│   ├── App.tsx
│   └── router.tsx
├── components/
│   ├── layout/
│   │   ├── Header.tsx
│   │   ├── Footer.tsx
│   │   └── Container.tsx
│   ├── events/
│   │   ├── EventCard.tsx
│   │   ├── EventGrid.tsx
│   │   ├── EventFilters.tsx
│   │   └── EventSearch.tsx
│   ├── tickets/
│   │   ├── TicketOption.tsx
│   │   └── TicketSelector.tsx
│   └── common/
│       ├── Button.tsx
│       ├── Input.tsx
│       ├── Loader.tsx
│       └── ErrorMessage.tsx
├── features/
│   ├── events/
│   ├── checkout/
│   ├── auth/
│   └── orders/
├── pages/
├── services/
│   ├── api.ts
│   ├── events.ts
│   ├── orders.ts
│   └── auth.ts
├── types/
│   ├── event.ts
│   ├── ticket.ts
│   └── order.ts
├── hooks/
├── utils/
├── styles/
└── main.tsx
```

This structure is a starting point, not a requirement to create every file immediately.

## 6. API Integration

The frontend communicates with the Rails API through a centralized HTTP client.

Responsibilities of the API layer:
- Define the API base URL through environment configuration.
- Serialize request payloads.
- Parse JSON responses.
- Handle HTTP errors consistently.
- Attach authentication credentials when required.
- Keep API communication separate from presentation components.

Potential endpoint groups:

| Resource | Example operation | Purpose |
|---|---|---|
| Events | `GET /events` | Retrieve events |
| Events | `GET /events/:id` | Retrieve event details |
| Orders | `POST /orders` | Create an order |
| Orders | `GET /orders/:id` | Retrieve an order |
| Authentication | `POST /login` | Sign in, if implemented |
| Authentication | `POST /register` | Register, if implemented |

The paths above are illustrative. Confirm the actual routes in the Rails application before implementing the services.

## 7. Environment Configuration

Use Vite environment variables for frontend configuration.

Example `.env.example`:

```env
VITE_API_BASE_URL=http://localhost:3000
```

Read the value using:

```typescript
const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
```

Only expose non-secret configuration to the browser. Variables prefixed with `VITE_` must never contain private API keys, database credentials, payment secrets, or other sensitive values.

Keep `.env` files containing local secrets out of version control.

## 8. Data Models

The frontend should define TypeScript types that match the actual API responses.

Illustrative event type:

```typescript
export interface Event {
  id: number;
  title: string;
  description: string;
  imageUrl: string | null;
  startsAt: string;
  venue: string;
  location: string;
}
```

Illustrative ticket type:

```typescript
export interface TicketOption {
  id: number;
  name: string;
  price: number;
  availableQuantity: number;
}
```

Illustrative order type:

```typescript
export interface Order {
  id: number;
  status: string;
  totalAmount: number;
  createdAt: string;
}
```

These fields are examples. Align property names, identifier types, money representation, and nullability with the Rails API contract.

## 9. UI States and Error Handling

Every data-driven page should account for the following states:

- **Loading:** data is being retrieved.
- **Success:** data has loaded and can be displayed.
- **Empty:** no matching events, orders, or tickets exist.
- **Error:** the request failed or returned an unexpected response.
- **Unavailable:** tickets cannot currently be purchased.
- **Submitting:** a checkout or authentication request is in progress.

Display clear feedback and prevent duplicate submissions where appropriate.

## 10. Security and Reliability

- Treat all browser input as untrusted.
- Perform authorization and validation on the backend.
- Do not trust prices or totals calculated exclusively in the browser.
- Recheck ticket availability and price during order creation.
- Prevent duplicate purchases caused by repeated submissions.
- Use secure authentication and session handling appropriate to the backend.
- Never expose payment provider secrets in frontend code.
- Provide accessible labels, keyboard navigation, and visible focus states.

## 11. Testing Strategy

Use Vitest and React Testing Library if they are part of the project.

Recommended coverage:
- Event cards render the expected information.
- Search and filters update the displayed event list.
- Ticket selection calculates the expected subtotal.
- Invalid quantities are rejected.
- Loading, empty, and error states render correctly.
- Checkout displays validation errors.
- Failed API requests are handled gracefully.
- Successful checkout displays the confirmed order.

Use mocked API responses for component tests. Test critical purchase and payment behavior against the backend or payment provider in an appropriate integration environment.

## 12. Definition of Done

A frontend feature is complete when:
- The page or component meets its acceptance criteria.
- API integration matches the documented backend contract.
- Loading, empty, success, and error states are handled.
- The layout works on mobile and desktop.
- Accessibility basics are addressed.
- Relevant automated tests pass.
- No sensitive credentials are exposed to the browser.
