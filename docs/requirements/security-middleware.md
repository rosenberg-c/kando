# API Middleware and Security

### `SEC-LOGIN-001`

Login endpoint enforces rate-limit lockout and returns `Retry-After` when blocked.

### `SEC-LOGIN-002`

Login limiter blocks keys after configured max failures.

### `SEC-LOGIN-003`

Login limiter evicts old keys when max entries are reached.

### `SEC-AUTH-001`

Refresh and logout endpoints enforce auth-abuse throttling for refresh-session operations.

### `SEC-AUTH-002`

When refresh/logout auth-abuse throttling blocks a request, the API responds with `429` and includes `Retry-After`.

### `SEC-AUTH-REFRESH-001`

Refresh token store operations reject expired refresh tokens and preserve explicit operation semantics (`Resolve` does not implicitly rotate or revoke).

### `MW-AUTH-001`

Auth middleware rejects requests with missing or invalid bearer tokens.

### `MW-AUTH-002`

Auth middleware attaches verified identity to request context.

### `MW-AUTH-003`

Auth middleware maps verifier unauthorized errors to `401`.

### `MW-AUTH-004`

Auth middleware maps unexpected verifier errors to `401` without calling next handler.

### `MW-AUTH-005`

Cookie-based auth login, refresh, and logout endpoints accept requests only when fetch metadata indicates `same-origin` or `same-site`.

### `MW-AUTH-006`

Cookie-based auth login, refresh, and logout endpoints accept requests only when `Origin` matches an allowed origin.

### `MW-AUTH-007`

Auth login, refresh, and logout responses include anti-caching headers (`Cache-Control: no-store`, `Pragma: no-cache`, and `Expires: 0`).

### `MW-AUTH-008`

Auth verification layer maps verifier availability failures to `503` without calling next handler.

### `MW-AUTH-009`

Kanban board/column/task endpoints accept either bearer-token auth or cookie-based access-token auth; when cookie-based auth is used, requests are accepted only when fetch metadata indicates `same-origin` or `same-site`. For `same-site` requests, `Origin` must match an allowed origin; for `same-origin` requests, `Origin` may be absent.

### `MW-REQID-001`

Request ID middleware preserves incoming request IDs in response and context.

### `MW-REQID-002`

Request ID middleware generates and propagates a request ID when missing.

### `MW-REQID-003`

Request ID middleware rejects invalid incoming request ID values and generates a safe request ID for response and context propagation.

### `MW-CORS-001`

API middleware handles browser CORS preflight (`OPTIONS`) requests for allowed origins and returns CORS allow headers.

### `MW-CORS-002`

API middleware includes CORS allow-origin headers for simple/actual requests from allowed origins and omits them for disallowed origins.
