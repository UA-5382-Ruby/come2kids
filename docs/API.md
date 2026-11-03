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

API errors use the same JSON shape for every endpoint:

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

## Running the API

To start the local development server, navigate to the API directory and run:

```bash
cd api
rails server