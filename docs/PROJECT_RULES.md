# Project Rules

These rules are specific to this project and take precedence over generic guidance in `docs/RULES.md` and `AGENT.md` when applicable.

## 1. Confirm migration strategy before applying it

When work introduces a migration situation, pause and confirm strategy with the user before implementation.

Examples include:

- data format or schema migrations
- API contract or protocol migrations
- requirement-reference convention changes
- generated-artifact workflow migrations

---

## 2. Keep APIs OpenAPI-compatible

- define new API behavior in an OpenAPI-compatible contract
- keep endpoints, schemas, and error responses generation-friendly
- avoid designs that block contract-first workflows

---

## 3. OpenAPI is the transport source of truth

- keep the API contract in `api/openapi.yaml` as the single transport source of truth
- generate transport models/clients from OpenAPI; do not handwrite duplicate DTOs or endpoint paths
- map between transport and domain models at boundary adapters
- keep generated artifacts read-only and regenerate on contract changes

---

## 4. Authentication is backend-owned

- clients authenticate through backend API endpoints only
- client apps must not call external auth/session providers directly
- backend owns provider secrets, token/session issuance, refresh, revocation, and verification

---

## 5. Requirements-first for behavior changes

- every new feature or observable behavior change must map to requirement IDs before implementation
- update `docs/requirements/*.md` first, then implement code and tests
- keep automated tests tagged with requirement references using `@req` comments
- keep `docs/TEST_MATRIX.md` synchronized via `cmd/sync_test_matrix`

---

## 6. Concurrency boundaries for Apple client code

- prefer `Sendable` service/model boundaries in `apps/apple`
- avoid broad `@MainActor` service/network/storage protocols
- scope `@MainActor` to UI-facing state and updates

---

## 7. Accessibility IDs are part of the UI contract

- assign stable accessibility identifiers to interactive controls and key containers
- use identifier-first UI test selectors with documented fallback only when needed
- provide explicit accessibility labels when visible text is symbolic or abbreviated

---

## 8. Collection mutations use list semantics

- model reorder and batch mutations as list-shaped requests
- validate list invariants at boundaries (membership, duplicates, ordering shape)
- apply collection mutations atomically where backend capabilities support it

---

## 9. Preserve requirement tag conventions

- keep test requirement annotations using `@req` comment markers
- keep requirement IDs globally unique and stable; do not recycle IDs
- keep UI requirement entries explicit about platform applicability states (`required`, `planned`, `N/A`)

---

## 10. Use typed conflict and validation error mapping

- represent conflict/validation categories with stable typed errors in domain/service layers
- map boundary status + response detail from typed categories, not fragile string parsing
- add tests when introducing new error categories at both domain and API boundaries

---

## 11. Keep backend behavior parity across supported repositories

- repository-facing features must be implemented consistently for `memory`, `sqlite`, and `appwrite`
- do not mark a feature complete while a supported backend still returns `ErrNotImplemented` unless requirements explicitly allow it
- add backend-specific tests for feature behavior and failure semantics

---

## 12. Generated transport contracts are read-only

- for `apps/apple` and CLI transport clients, rely on OpenAPI-generated contracts instead of handwritten DTO/path duplicates
- if domain-friendly shapes are needed, map generated transport types at boundary adapters
- regenerate artifacts before changing client behavior tied to contract updates

---

## 13. Go-specific safety and boundary defaults

- never take the address of range loop variables; index into slices when pointer identity is required
- use `filepath.Join` for filesystem paths
- pass `context.Context` through I/O or request-scoped boundaries; do not store context on structs
- return errors (with wrapping context) instead of panicking for expected failures

---

## 14. Logging and secret-handling constraints

- log at service/HTTP/CLI boundaries, not as a replacement for returned errors
- never log credentials, tokens, API keys, or provider secrets
- when logging external provider payloads, use redacted summaries only

---

## 15. UI mutation single-flight behavior is required

- disable destructive or mutating controls immediately while requests are in flight
- prevent duplicate tap/click mutation requests for the same action
- cover disabled/enabled transitions with automated tests for critical flows

---

## 16. Maintainability scope while delivering features

- small adjacent maintenance in touched areas is allowed when behavior-preserving and low risk
- broad or cross-cutting refactors should be discussed before implementation
- clearly separate feature behavior changes from adjacent cleanup in change notes

---

## 17. Promote reusable base UI to `packages/components`

- avoid styling base HTML elements globally (for example `button`, `p`, `h1`, `input`) in feature or app stylesheets
- when a base element needs shared visual treatment across composites/pages, implement it as a reusable component in `apps/web/react/packages/components`
- keep feature/package styles focused on layout and feature-specific variants; compose shared base primitives (`Button`, `Text`, etc.) instead of duplicating base element styling
