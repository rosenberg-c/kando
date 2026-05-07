# Auth Security Hardening Follow-up

## 1) Replace in-memory refresh token store

- Current `RefreshTokenStore` is process-local memory and does not survive restart.
- Move refresh token state to a shared durable backend (Redis/DB) with TTL support.
- Require atomic rotate+revoke semantics to avoid replay windows under concurrency.
- Add backend-parity coverage for `memory`, `sqlite`, and `appwrite` integration paths.

## 2) Device/session fingerprint support

- Feasible, but should be staged carefully to avoid breaking legitimate users (mobile IP churn, VPN, browser privacy changes).
- Start with soft-binding and telemetry:
  - persist non-secret session metadata at login (user agent family, coarse network signal, issued-at)
  - evaluate mismatch on refresh and emit security events
  - block only on high-confidence abuse signals
- If desired later, enforce stronger binding for native clients first (stable device identifier model), then web.

## 3) Login abuse hardening beyond lockout

- Current lockout model is account/IP threshold only.
- Add progressive controls:
  - exponential backoff/jitter after repeated failures
  - per-account and per-IP rolling windows with burst limits
  - optional challenge/captcha gate after sustained abuse
- Add dashboards/alerts on lockout spikes and refresh-failure spikes.

## 4) Make refresh operation failure-safe

- Status: implemented in server refresh handlers.
- Refresh now resolves token/session first, mints JWT, and only then rotates refresh token state.
- Remaining risk: concurrent refresh attempts can still race; one request may rotate first and the other may fail rotation. This is acceptable single-use behavior, but should be documented in client retry/UX expectations.

## 5) Add abuse controls to refresh/logout endpoints

- Status: implemented baseline rate-limiting.
- Refresh/logout now enforce auth action throttling using per-IP and token-hash scoped keys before sensitive operations.
- Responses return `429` with `Retry-After` via typed auth error mapping.
- Follow-up: tune thresholds from production telemetry and add explicit dashboards/alerts for sustained rejection spikes.

## 6) Clean up provider session on local refresh-issue failure

- During login, if refresh token issuance fails after provider session creation, the provider session can remain active without local mapping.
- Add best-effort `DeleteSession` cleanup path after refresh issuance failure.
- Add tests for cleanup behavior and non-leak failure semantics.

## 7) Align CLI auth transport with native endpoint requirements

- CLI should use `/auth/native/login`, `/auth/native/refresh`, and `/auth/native/logout` consistently.
- Verify generated client bindings and CLI API client wiring do not call browser cookie endpoints.
- Add requirement-linked tests validating native endpoint usage and response-shape assumptions.

## 8) Persist auth-abuse limiter state in shared durable storage

- Current login/auth abuse limiters are process-local memory.
- Move limiter counters/windows to shared durable storage (Redis/DB) so lockout and throttling are consistent across restarts and multi-instance deployments.
- Keep per-key TTL semantics and `Retry-After` behavior equivalent to current API contracts.
- Add multi-instance parity/integration tests for limiter behavior.
