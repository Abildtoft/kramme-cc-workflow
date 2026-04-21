# Error shapes

Reference material for Rule 3 of `kramme:code:api-design`. Every error response in the API uses the same body shape and the same status-to-meaning mapping.

## The `APIError` shape

```ts
type APIError = {
  code: string;       // stable, machine-readable identifier
  message: string;    // human-readable, safe for end-users
  details?: unknown;  // optional structured context (field-level errors, retry hints, etc.)
};
```

Rules for each field:

- **`code`** — a stable identifier callers can branch on. Kebab-case or snake_case, consistent across the whole API. Examples: `invalid-email`, `task-not-found`, `rate-limited`. Never change an existing code; add a new one and deprecate the old one if needed. Hyrum's Law applies: someone is branching on this string.
- **`message`** — free-form human text. Safe to show to end-users; never contains stack traces, internal paths, user IDs from other accounts, or database column names.
- **`details`** — optional. Used when a client benefits from structured context. Most common shape is field-level validation errors: `{ fields: { email: "invalid-format", password: "too-short" } }`.

Minimal error response body:

```json
{
  "code": "task-not-found",
  "message": "No task exists with that ID."
}
```

With `details`:

```json
{
  "code": "validation-failed",
  "message": "Some fields were invalid.",
  "details": {
    "fields": {
      "email": "invalid-format",
      "dueDate": "must-be-future-date"
    }
  }
}
```

## HTTP status mapping

| Status | Meaning |
|---|---|
| 400 | Invalid data |
| 401 | Not authenticated |
| 403 | Not authorized |
| 404 | Not found |
| 409 | Conflict |
| 422 | Validation failed |
| 500 | Server error (never expose internals) |

### Worked examples

**400 — Invalid data.** The request body cannot be parsed at all, or a required field is missing. Not the same as 422 (which is for a parsed request whose values are invalid).

```
POST /tasks
{ "title": }           ← malformed JSON

→ 400
{ "code": "invalid-request", "message": "Request body could not be parsed." }
```

**401 — Not authenticated.** No credentials, expired credentials, or invalid credentials.

```
GET /me                ← no Authorization header

→ 401
{ "code": "not-authenticated", "message": "Authentication required." }
```

**403 — Not authorized.** Credentials are valid but this user is not allowed to do this.

```
DELETE /tasks/abc      ← task belongs to another user

→ 403
{ "code": "forbidden", "message": "You do not have permission to delete this task." }
```

Note: returning 404 instead of 403 for resources the caller should not even know exist is a valid pattern (prevents resource-enumeration). Pick one per resource class and stay consistent.

**404 — Not found.** The resource does not exist, or the caller should be treated as if it does not exist.

```
GET /tasks/does-not-exist

→ 404
{ "code": "task-not-found", "message": "No task exists with that ID." }
```

**409 — Conflict.** The request conflicts with the current server state. Classic case: unique-constraint violation, optimistic-concurrency mismatch.

```
POST /users
{ "email": "a@example.com" }   ← already registered

→ 409
{ "code": "email-already-registered", "message": "An account with that email already exists." }
```

**422 — Validation failed.** The request was parsed successfully, but the values do not satisfy the schema's semantic constraints.

```
POST /tasks
{ "title": "", "dueDate": "2020-01-01" }

→ 422
{
  "code": "validation-failed",
  "message": "Some fields were invalid.",
  "details": {
    "fields": { "title": "must-not-be-empty", "dueDate": "must-be-future-date" }
  }
}
```

**500 — Server error.** Something went wrong on the server. **Never expose internals.** No stack traces, no file paths, no SQL snippets, no library versions, no internal IDs. The message should be generic; the real failure goes to server logs with a correlation ID the client can quote back.

```
→ 500
{ "code": "internal-error", "message": "An unexpected error occurred.", "details": { "requestId": "req_abc123" } }
```

The `requestId` is safe because it is meaningless without server-side logs.

## 500-disclosure note

The single most common API leak is a 500 response that exposes internals — a stack trace, a library version (fingerprints for CVE scanning), an internal hostname, a database column name, or the path of a source file. Every 500 response path must be audited for disclosure. If the handler framework prints stack traces by default, the boundary must strip them before the response leaves the server.

A useful test: would it be safe to publish this 500 response on a public status page? If not, the error body is leaking something.
