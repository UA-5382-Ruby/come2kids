# API Error Codes

Every error response uses the same JSON body, so the frontend can handle failures uniformly.

```json
{
  "code": "validation_failed",
  "message": "Validation failed",
  "details": { "fields": { "email": ["can't be blank"] } }
}
```

| Field     | Type   | Description                                                                                  |
|-----------|--------|----------------------------------------------------------------------------------------------|
| `code`    | string | Stable, machine-readable identifier. Clients should branch on this, never on `message`.      |
| `message` | string | Human-readable description. Safe to log, may change between releases. Do not parse it.       |
| `details` | object | Extra context. Always present, `{}` when there is nothing to add. Shape depends on the code. |

**Source of truth:** `api/lib/api/error_codes.rb` (`Api::ErrorCodes::CATALOG`). When you add or change a code there, update this file in the same PR.

**Stability:** codes are part of the public contract. Adding a code is safe. Renaming or removing one is a breaking change.

---

## Catalog

| Code                | HTTP status | Meaning                                                              |
|---------------------|-------------|----------------------------------------------------------------------|
| `bad_request`       | 400         | The request is malformed or a required parameter is missing.         |
| `invalid_parameter` | 400         | A query parameter (`page`, `pageSize`, `sort`, `filter`) is invalid. |
| `unauthorized`      | 401         | Authentication is missing, expired, or invalid.                      |
| `forbidden`         | 403         | The user is authenticated but not allowed to perform this action.    |
| `not_found`         | 404         | The resource or route does not exist.                                |
| `conflict`          | 409         | The request conflicts with the current state of the resource.        |
| `validation_failed` | 422         | The submitted data failed validation.                                |
| `internal_error`    | 500         | Unexpected server error. No internal details are exposed.            |

---

## Details by code

### `bad_request` (400)

Returned when the body cannot be parsed or a required parameter is missing.

Missing required parameter:

```json
{
  "code": "bad_request",
  "message": "param is missing or the value is empty: order",
  "details": { "param": "order" }
}
```

Malformed JSON body:

```json
{
  "code": "bad_request",
  "message": "Malformed request body",
  "details": {}
}
```

### `invalid_parameter` (400)

Returned when pagination, sorting, or filter parameters are invalid.

Invalid pagination value (`?pageSize=abc` or `?page=0`):

```json
{
  "code": "invalid_parameter",
  "message": "Invalid query parameter",
  "details": { "param": "pageSize" }
}
```

Disallowed sort field (`?sort=password`):

```json
{
  "code": "invalid_parameter",
  "message": "Invalid query parameter",
  "details": { "param": "sort", "allowed": ["created_at", "amount_minor"] }
}
```

Invalid timestamp in a filter (`?filter[created_from]=yesterday`):

```json
{
  "code": "invalid_parameter",
  "message": "Invalid query parameter",
  "details": { "param": "created_from" }
}
```

### `unauthorized` (401)

Returned when credentials are missing or invalid. The client should send the user to login or refresh the token.

```json
{
  "code": "unauthorized",
  "message": "Authentication required",
  "details": {}
}
```

### `forbidden` (403)

Returned when the user is authenticated but lacks permission.

```json
{
  "code": "forbidden",
  "message": "You are not allowed to perform this action",
  "details": {}
}
```

### `not_found` (404)

Returned when a record does not exist (`ActiveRecord::RecordNotFound`):

```json
{
  "code": "not_found",
  "message": "Resource not found",
  "details": { "resource": "Order" }
}
```

Returned when no route matches:

```json
{
  "code": "not_found",
  "message": "Route not found",
  "details": {}
}
```

### `conflict` (409)

Returned when the request clashes with current state, such as a duplicate unique value or an invalid state transition. The `details` shape is defined by the code that raises it. Keep it small and document each use here.

```json
{
  "code": "conflict",
  "message": "Order is already paid",
  "details": { "resource": "Order", "state": "paid" }
}
```

### `validation_failed` (422)

Returned when a record fails validation (`ActiveRecord::RecordInvalid`). `details.fields` maps each attribute to an array of error messages.

```json
{
  "code": "validation_failed",
  "message": "Validation failed",
  "details": {
    "fields": {
      "email": ["can't be blank", "is invalid"],
      "amount_minor": ["must be greater than 0"]
    }
  }
}
```

### `internal_error` (500)

Returned for any unhandled exception. The message is always generic and `details` is always empty. The real error is written to the server log (and the error tracker, when configured), never to the response.

```json
{
  "code": "internal_error",
  "message": "Internal server error",
  "details": {}
}
```

---

## Handling errors in the frontend

- Branch on `code`, not on `message` or the HTTP status alone.
- Show `details.fields` next to form inputs for `validation_failed`.
- Treat `unauthorized` as a signal to re-authenticate.
- Treat `internal_error` as retryable at the user's discretion, and show a generic message.
- Unknown codes: fall back to the HTTP status class (4xx vs 5xx) so new codes don't break old clients.

---

## Adding a new error code

1. Add the entry to `Api::ErrorCodes::CATALOG` in `api/lib/api/error_codes.rb` with its status and default message.
2. Raise it with `raise Api::Error.new(:your_code, details: { ... })`, or map an exception to it in `ErrorHandler`.
3. Add an integration test in `api/test/integration/` asserting the status and the `{ code, message, details }` keys.
4. Document it in this file: a row in the catalog table and an example under "Details by code".
5. Add it to the `Error` schema examples in rswag if it appears in an endpoint's responses.