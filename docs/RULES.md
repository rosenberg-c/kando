# Go Engineering Rules

## 1. Do not take addresses of range loop variables

Range variables are reused across iterations.

**Bad:**

```go
for _, v := range slice {
    return &v
}
```

**Good:**

```go
for i := range slice {
    return &slice[i]
}
```

---

## 2. Build file paths with `filepath.Join`

* Avoid string concatenation for paths
* Ensures cross-platform correctness

```go
path := filepath.Join(basePath, "file.json")
```

---

## 3. Choose values vs pointers based on semantics

Do not default to one or the other.

Use **values** when:

* data is small and immutable
* you want clear ownership and no shared mutation

Use **pointers** when:

* mutation is required
* structs are large
* optional fields are needed (`nil`)
* identity matters

If returning pointers:

* ensure they point to stable memory (not loop variables)

---

## 4. Validate invariants at boundaries

* enforce uniqueness (IDs, usernames) on create
* validate inputs before mutating state
* return explicit domain errors

```go
var ErrAlreadyExists = errors.New("already exists")
```

---

## 5. Treat persistence as slow and failure-prone

* expect I/O to fail
* wrap errors with context

```go
return fmt.Errorf("save user: %w", err)
```

* avoid unnecessary full read–modify–write cycles

---

## 6. Protect shared state with synchronization

* use `sync.Mutex` or `sync.RWMutex` when concurrent access is possible
* file-backed storage is not concurrency-safe by default

---

## 7. Design for testability with dependency injection

Prefer dependency injection at boundaries.

**Bad:**

```go
NewRepo(path string)
```

**Good:**

```go
NewRepo(store Store)
```

Guidelines:

* avoid hardcoding file paths, globals, or environment access
* inject dependencies explicitly
* use real implementations in tests when practical

---

## 8. Document exported symbols meaningfully

* exported types and functions should generally have comments
* comments should explain behavior, not restate names

Focus on:

* error conditions
* side effects
* concurrency guarantees
* invariants and assumptions

**Bad:**

```go
// GetByID gets by ID
```

**Good:**

```go
// GetByID returns ErrNotFound if no user with the given ID exists.
```

---

## 9. Nil slices are valid

* returning `nil` slices is idiomatic
* only return empty slices when required by JSON/API contracts

---

## 10. Use `context.Context` at boundaries

Accept `context.Context` in functions that:

* perform I/O
* may block
* are request-scoped

```go
func (r *Repo) GetByID(ctx context.Context, id string) (User, error)
```

Rules:

* do not store context in structs
* pass it through call chains
* use only for cancellation, deadlines, and request-scoped values

---

## 11. Use interfaces deliberately

Use interfaces only when they provide real value.

Use interfaces when:

* you need to decouple a consumer from an implementation
* multiple implementations are expected
* you want to isolate external dependencies (I/O, storage, APIs)

Avoid interfaces when:

* there is only one implementation
* they are introduced “just in case”
* they duplicate a concrete type without adding value

Prefer:

* defining interfaces at the point of use (consumer)
* small, focused interfaces
* concrete types until abstraction is needed

**Bad:**

```go
type UserRepository interface {
    Create(...)
    Update(...)
    Delete(...)
    Get(...)
}
```

**Better:**

```go
type UserGetter interface {
    GetByID(ctx context.Context, id string) (User, error)
}
```

---

## 12. Separate domain, transport, and storage models

Do not couple core domain structs to:

* JSON shape
* database schema
* OpenAPI-generated types

Use mapping at boundaries:

```txt
[Transport DTO] <-> [Domain Model] <-> [Storage Model]
```

---

## 13. Return errors, don’t panic

* use `error` for expected failures
* panic only for truly unrecoverable programmer errors

---

## 14. Keep functions small and explicit

* prefer simple, readable functions over clever abstractions
* make data flow obvious
* avoid hidden side effects

---

## 15. Be explicit about concurrency

Do not introduce goroutines without clear ownership.

Always answer:

* who starts it
* who stops it
* how errors are handled

---

## 16. Favor composition over inheritance-style patterns

* embed structs for reuse
* avoid deep abstraction hierarchies

---

## 17. Logging is not error handling

* return errors to callers
* log only at boundaries (HTTP layer, CLI entrypoint, etc.)
* use explicit, structured log messages with stable keys (for example `request_id=... route=... error=...`)
* never log credentials, bearer tokens, refresh tokens, session secrets, or API keys
* when logging external error payloads, use redacted summaries only

---

## 18. Treat file-backed storage as a prototype

File storage is not suitable for:

* high concurrency
* large datasets
* distributed systems

Design so it can be replaced later.

---

## 19. Test behavior, not implementation

Write tests that validate observable behavior.

Prefer:

* testing public APIs and behavior
* verifying outputs, errors, and side effects
* real implementations when fast and deterministic

Avoid:

* asserting on internal/private details
* unnecessary mocking
* tests dependent on timing, globals, or external systems

Guidelines:

* use table-driven tests for logic
* test errors explicitly with `errors.Is`
* keep tests fast and deterministic
* if code is hard to test, simplify the design

---

## 20. Authentication is a server concern

Authentication integration belongs only to the backend.

Rules:

* clients must authenticate through backend API endpoints only
* clients must not call external auth providers directly
* clients must not handle provider secrets, server API keys, or provider session management
* backend owns token/session issuance, refresh, revocation, validation, and secret handling

Forbidden examples:

* `apps/cli` importing provider SDKs or `internal/appwrite`
* `apps/apple` calling provider auth/session endpoints directly
* any client reading `APPWRITE_*` server secrets

---

## 21. UI text must be externalized

UI-facing copy must not be hardcoded in views/components.

Rules:

* define UI strings in resource files, grouped by feature/domain
* use a shared lookup layer (for example `t("auth.login.title")`)
* keep common shared labels in a small `common` namespace
* avoid one giant global strings file and avoid per-file ad hoc string constants

Suggested structure:

* `ui/strings/en/common.json`
* `ui/strings/en/auth.json`
* `ui/strings/en/tasks.json`

---

## 22. Prefer `Sendable` boundaries; scope `@MainActor` to UI state

For Swift code (especially in `apps/apple`), default to concurrency-safe service boundaries.

Rules:

* prefer protocol and model boundaries that are `Sendable`
* avoid `@MainActor` on service/network/storage protocols by default
* use `@MainActor` for UI-facing state and updates (for example SwiftUI views, `ObservableObject` UI state)
* if a type is `@MainActor`, document why main-thread affinity is required

Rationale:

* keeps network/storage work off the UI actor
* reduces accidental serialization on the main thread
* improves testability and compatibility with strict Swift concurrency checks

---

## 23. Use list-based APIs for collection-scoped mutations

When an operation mutates a collection as a whole (for example reorder, batch actions, or membership updates), expose a list-based request interface.

Rules:

* accept the intended collection result as a list payload
* validate list semantics at the boundary (membership, duplicates, shape)
* apply the mutation atomically (all-or-nothing)
* do not add parallel single-item action endpoints for the same collection behavior

---

## 24. Accessibility identifiers and labels are required for UI controls

For UI code (especially in `apps/apple`), treat accessibility hooks as part of the contract.

Rules:

* assign stable accessibility identifiers to interactive controls and key containers
* prefer identifier-based UI tests over visible text matching
* keep identifier naming consistent and feature-scoped (for example `board-edit-close-button`)
* when visible text is symbolic or abbreviated (for example `<`, `>`, arrows, icons), add explicit accessibility labels with clear wording
* keep display text and accessibility text as separate localized keys when needed
* if XCTest/macOS automation cannot reliably resolve a custom accessibility identifier for a control, use an identifier-first selector with a text fallback and document the fallback in the test

Suggested string-key pattern:

* `feature.action` for display text
* `feature.action.accessibility` for accessibility label

Example:

* `board.column.move_left` = `<`
* `board.column.move_left.accessibility` = `Move left`

---

## 25. Maintenance scope while implementing features

Small maintenance in adjacent code is allowed and encouraged when it improves quality without changing scope.

Rules:

* you may include minor adjacent maintenance (for example naming cleanup, small refactors, test selector hardening, dead-code removal, typo fixes)
* keep adjacent maintenance low risk, reversible, and directly related to touched areas
* if a discovered issue is medium/large scope or changes behavior beyond the requested feature, stop and discuss before editing
* when making adjacent maintenance changes that are not the primary feature, commit them separately from the main feature changes
* in PR/commit notes, clearly distinguish primary feature work from adjacent maintenance

Examples of discuss-first work:

* broad architecture refactors
* migration or data-shape changes outside request scope
* cross-cutting behavior changes across multiple modules

---
