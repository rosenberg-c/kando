# API Middleware and Security

- `SEC-LOGIN-001`: Login endpoint enforces rate-limit lockout and returns `Retry-After` when blocked.
- `SEC-LOGIN-002`: Login limiter blocks keys after configured max failures.
- `SEC-LOGIN-003`: Login limiter evicts old keys when max entries are reached.
- `MW-AUTH-001`: Auth middleware rejects requests with missing or invalid bearer tokens.
- `MW-AUTH-002`: Auth middleware attaches verified identity to request context.
- `MW-AUTH-003`: Auth middleware maps verifier unauthorized errors to `401`.
- `MW-AUTH-004`: Auth middleware maps verifier operational errors to `401` without calling next handler.
- `MW-REQID-001`: Request ID middleware preserves incoming request IDs in response and context.
- `MW-REQID-002`: Request ID middleware generates and propagates a request ID when missing.
