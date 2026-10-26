# API Reference

## Overview

Come2Kids API is a Ruby on Rails backend. This document is intended to summarize the application's HTTP endpoints and their expected behavior.

**Implementation status:** The endpoint list below is a template. Confirm each route against `bin/rails routes` and the corresponding controller before treating it as implemented.

## Base URL

Development:

`http://localhost:3000`

## Endpoint documentation format

For each endpoint, document:

- HTTP method and path
- Purpose
- Authentication requirements
- Request parameters or body
- Successful response
- Possible error responses

## Endpoint inventory

| Method | Path | Purpose | Status |
|---|---|---|---|
| GET | `/` | Application root or health check, if configured | Verify |
| GET | `/resources` | List resources, if implemented | Verify |
| GET | `/resources/:id` | Retrieve a resource, if implemented | Verify |
| POST | `/resources` | Create a resource, if implemented | Verify |
| PATCH | `/resources/:id` | Update a resource, if implemented | Verify |
| DELETE | `/resources/:id` | Delete a resource, if implemented | Verify |

Replace `/resources` with actual resource paths. These examples do not confirm that the endpoints exist.

## HTTP status codes

Use status codes that accurately reflect the result:

- `200 OK` — request completed successfully.
- `201 Created` — a resource was created.
- `204 No Content` — request succeeded without a response body.
- `400 Bad Request` — request is malformed.
- `401 Unauthorized` — authentication is required or invalid.
- `403 Forbidden` — the caller is not allowed to perform the operation.
- `404 Not Found` — the requested resource does not exist.
- `422 Unprocessable Entity` — validation failed.
- `500 Internal Server Error` — an unexpected server-side error occurred.

Use only the codes relevant to each endpoint.

## Discovering available routes

Run:

```bash
bin/rails routes
```

Use the output to update this reference with the real HTTP methods, paths, and controller actions.

## Request and response examples

Add JSON examples for each implemented endpoint, including required fields, response attributes, and validation errors. Do not document authentication schemes or payload fields until they have been confirmed in the implementation.
