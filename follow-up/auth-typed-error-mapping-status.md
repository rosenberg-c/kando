# Auth Typed Error Mapping Status

## Implemented

- Auth API boundary errors are now centralized through stable typed categories in `server/internal/api/server/register_auth.go`.
- `authErrorCode` constants define canonical categories (for example `login_failed`, `refresh_failed`, `logout_failed`, `missing_bearer_token`, `verifier_unavailable`).
- `authAPIError(...)` maps these categories to HTTP status + response message consistently.
- Auth handlers and identity guard now use this mapping instead of scattered ad-hoc `huma.Error...` calls.

## Why this helps

- Aligns with `docs/RULES.md` rule 16 and `docs/PROJECT_RULES.md` rule 10 (typed error mapping at boundaries).
- Reduces drift risk across auth endpoints.
- Makes future category expansion safer and more testable.

## Remaining follow-up

- Add explicit tests that assert category-to-boundary mapping for key auth failure paths.
- If auth error categories are needed outside server package boundaries, promote them into a small shared auth error type module.
