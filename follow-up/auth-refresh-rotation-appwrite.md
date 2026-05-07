# Auth Refresh Rotation Follow-up

## Context

Current auth refresh flows rotate local refresh tokens, but do not rotate the underlying Appwrite provider session secret on refresh.

## Why deferred

Appwrite docs do not expose a single explicit "rotate refresh session" endpoint.

Documented primitives are:

- mint JWT from current session (`POST /account/jwts`)
- delete session (`DELETE /account/sessions/{sessionId}` / `DELETE /users/{userId}/sessions/{sessionId}`)
- create user session (`POST /users/{userId}/sessions`)

Rotation may be possible via multi-step composition, but requires careful handling of user/session mapping and atomicity/failure behavior.

## Next step

Design and validate a safe multi-step rotation strategy for Appwrite-backed refresh, then implement issuer/server changes if acceptable.

## Deployment note (current vs future)

Current plan is same-machine/same-site frontend and backend, so current browser cookie policy (`SameSite=Lax`, `Secure`, `HttpOnly`) and fetch metadata checks (`same-origin` or `same-site`) are acceptable for now.

If deployment changes to cross-site frontend/backend, revisit auth cookie and CSRF strategy:

- cookie policy likely needs `SameSite=None; Secure`
- keep strict origin allowlist and CORS credential handling
- add stronger CSRF defense (for example explicit CSRF token validation on cookie-auth mutation endpoints)
