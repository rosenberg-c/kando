# Appwrite Integration and Auth Adapter

## Integration

- `APPWRITE-001`: Appwrite persistence matches kanban domain rules.
- `APPWRITE-002`: Row listing supports pagination.
- `APPWRITE-003`: Integration tests for Appwrite behavior are opt-in and environment-gated.
- `APPWRITE-004`: Appwrite does not currently provide atomic guarantees for task batch delete; backend behavior is a documented sequential fallback.

## Auth Adapter

- `APPWRITE-AUTH-001`: Creating an email/password session sends the expected endpoint path and project header.
- `APPWRITE-AUTH-002`: Creating an email/password session sends the configured API key header.
- `APPWRITE-AUTH-003`: Creating a JWT uses the current Appwrite session secret.
- `APPWRITE-AUTH-004`: Verifying a JWT returns identity data and does not send server API key headers.
- `APPWRITE-AUTH-005`: Verifying an unauthorized JWT maps to `auth.ErrUnauthorized`.
- `APPWRITE-AUTH-006`: Deleting a session calls the current-session delete endpoint with session header.
- `APPWRITE-AUTH-007`: External error summaries redact sensitive terms.
- `APPWRITE-AUTH-008`: External error summaries truncate oversized payloads.
