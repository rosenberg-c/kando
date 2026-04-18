# Authentication Flow

This project uses Appwrite as the authentication source of truth for all clients.

## Goals

- Keep domain authorization decisions in the Go API.
- Keep identity and session lifecycle in Appwrite.
- Ensure CLI and other clients can act on behalf of users safely.

## End-to-end flow

1. CLI login
   - User runs `todo login --email ...` and enters password at prompt.
   - For automation, use `todo login --email ... --password-stdin`.
   - CLI sends credentials to Go backend `POST /auth/login`.
   - Backend calls Appwrite to create session and JWT.
   - Backend returns access token + refresh token + expiry.
   - CLI stores access token state in local config and refresh token in macOS Keychain.

2. Authenticated API request
   - CLI calls Go backend endpoints with `Authorization: Bearer <access token>`.
   - Backend auth middleware verifies the JWT by resolving `/account` via Appwrite.
   - Backend maps Appwrite identity into request context.
   - Protected handlers (for example `/me`) read identity from context.

3. Token refresh
   - CLI calls backend `POST /auth/refresh` with refresh token when access token is near expiry.
   - Backend asks Appwrite for a new JWT and returns a refreshed access token.
   - If backend returns `401`, CLI refreshes once and retries the request.

4. Logout
   - CLI calls backend `POST /auth/logout`.
   - Backend revokes the Appwrite session using refresh token context.
   - CLI clears local auth state and keychain refresh token.

## Boundary rule

- CLI talks only to Go backend.
- Only backend talks to Appwrite.
- Authentication is a server concern.
- Clients do not manage provider sessions, provider secrets, or provider API keys.

## Security considerations

- Do not embed Appwrite API keys in CLI binaries.
  - CLI binaries are distributable artifacts and should be treated as untrusted.
  - Embedded server keys can be extracted and abused.
- Keep API keys server-side only.
  - Use server keys only in trusted backend infrastructure.
  - Scope keys to the minimum permissions required.
- Store local auth material with restrictive filesystem permissions.
  - Access token state files should be writable/readable by the current user only.
  - On macOS, refresh tokens are stored in Keychain.
- Use short-lived JWTs and refresh when needed.
  - Limits impact of token leakage.
- Apply login rate limiting and temporary lockout.
  - Reduces brute-force risk on `/auth/login`.
- Keep auth logs explicit and redacted.
  - Never log passwords, bearer tokens, refresh tokens, session secrets, or API keys.
  - Log only redacted external error summaries.

## Required environment variables

- `.env.server`
- `APPWRITE_ENDPOINT` (for example `https://<REGION>.cloud.appwrite.io/v1`)
- `APPWRITE_PROJECT_ID`
- `APPWRITE_AUTH_API_KEY` (server-side only, with `sessions.write` scope)

- `.env.app`
- `TODO_API_BASE_URL` (optional for CLI; default `http://localhost:8080`)

## References

- https://appwrite.io/docs/products/auth
- https://appwrite.io/docs/products/auth/email-password
- https://appwrite.io/docs/products/auth/jwt
